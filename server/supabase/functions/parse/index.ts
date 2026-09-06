import { canonicalizeUrl, parseLink, type ParseResult } from "../_shared/parse/index.ts";
import { sha256Hex } from "../_shared/hash.ts";
import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { ApiError, json, readJson, requireMethod, serve } from "../_shared/respond.ts";
import { serviceClient } from "../_shared/supabase.ts";

const cacheTtlMs = 24 * 60 * 60 * 1000;

function requireUrl(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > 2048) {
    throw new ApiError("invalid_request", "url is required");
  }
  let url: URL;
  try {
    url = new URL(value.trim());
  } catch {
    throw new ApiError("invalid_request", "url is not a valid URL");
  }
  if (url.protocol !== "https:" && url.protocol !== "http:") {
    throw new ApiError("invalid_request", "url must be http or https");
  }
  return url.toString();
}

async function readCache(hash: string): Promise<ParseResult | null> {
  const { data, error } = await serviceClient()
    .from("parse_cache")
    .select("payload, fetched_at")
    .eq("url_hash", hash)
    .maybeSingle<{ payload: ParseResult; fetched_at: string }>();
  if (error || !data) return null;
  if (Date.now() - new Date(data.fetched_at).getTime() > cacheTtlMs) return null;
  return data.payload;
}

async function writeCache(hash: string, payload: ParseResult): Promise<void> {
  const { error } = await serviceClient()
    .from("parse_cache")
    .upsert({ url_hash: hash, payload, fetched_at: new Date().toISOString() }, {
      onConflict: "url_hash",
    });
  if (error) console.error("parse cache write failed", error);
}

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "POST");
  await enforceRateLimit(req, "parse", buckets.parse);

  const body = await readJson<{ url?: unknown }>(req);
  const url = requireUrl(body.url);

  let canonicalURL: string;
  try {
    canonicalURL = await canonicalizeUrl(url);
  } catch {
    throw new ApiError("invalid_request", "url is not a valid URL");
  }

  const hash = await sha256Hex(canonicalURL);
  const cached = await readCache(hash);
  if (cached) return json(cached);

  const result: ParseResult = await parseLink(canonicalURL);
  if (result.title !== null || result.imageURL !== null) await writeCache(hash, result);

  return json(result);
}

serve(handle);
