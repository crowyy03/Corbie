import { parseHtml } from "../html.ts";
import { adapterForHost } from "./adapters/index.ts";
import { safeFetch } from "./guard.ts";
import { extractJsonLd } from "./jsonld.ts";
import { browserUserAgent, hostOf, normalizeUrl, resolveShortLink } from "./normalizeUrl.ts";
import { fetchOEmbed } from "./oembed.ts";
import { extractOpenGraph } from "./og.ts";
import {
  emptyFields,
  mergeFields,
  type ParseResult,
  type ParseSource,
  type ProductFields,
} from "./types.ts";

export * from "./types.ts";

const upstreamTimeoutMs = 8000;
const maxHtmlBytes = 3 * 1024 * 1024;
const maxTitleLength = 300;

export function sourceForHost(host: string): ParseSource {
  if (host === "instagram.com" || host.endsWith(".instagram.com")) return "instagram";
  if (host === "tiktok.com" || host.endsWith(".tiktok.com")) return "tiktok";
  return adapterForHost(host)?.source ?? "generic";
}

export function extractFields(html: string, host: string): ProductFields {
  const doc = parseHtml(html);
  const adapter = adapterForHost(host);
  const generic = mergeFields(extractJsonLd(doc), extractOpenGraph(doc));
  return adapter ? mergeFields(adapter.extract(doc), generic) : generic;
}

function absolute(candidate: string | null, base: string): string | null {
  if (!candidate) return null;
  try {
    const url = new URL(candidate, base);
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;
    return url.toString();
  } catch {
    return null;
  }
}

function tidy(fields: ProductFields, canonicalURL: string): ProductFields {
  const title = fields.title ? fields.title.slice(0, maxTitleLength).trim() : null;
  return {
    title: title && title.length > 0 ? title : null,
    price: fields.price,
    currency: fields.price === null ? null : fields.currency,
    imageURL: absolute(fields.imageURL, canonicalURL),
    author: fields.author ? fields.author.slice(0, maxTitleLength).trim() : null,
  };
}

async function readCapped(body: ReadableStream<Uint8Array>): Promise<Uint8Array> {
  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (total < maxHtmlBytes) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    total += value.length;
  }
  await reader.cancel().catch(() => {});

  const capped = new Uint8Array(Math.min(total, maxHtmlBytes));
  let offset = 0;
  for (const chunk of chunks) {
    if (offset >= capped.length) break;
    const room = capped.length - offset;
    capped.set(chunk.length > room ? chunk.subarray(0, room) : chunk, offset);
    offset += Math.min(chunk.length, room);
  }
  return capped;
}

async function readHtml(response: Response): Promise<string | null> {
  const type = response.headers.get("content-type") ?? "";
  if (type.length > 0 && !type.toLowerCase().includes("html")) {
    await response.body?.cancel();
    return null;
  }
  if (!response.body) return null;
  const capped = await readCapped(response.body);
  return new TextDecoder("utf-8", { fatal: false }).decode(capped);
}

export async function canonicalizeUrl(
  rawUrl: string,
  fetchImpl: typeof fetch = safeFetch,
): Promise<string> {
  return normalizeUrl(await resolveShortLink(rawUrl.trim(), fetchImpl));
}

export async function parseLink(
  rawUrl: string,
  fetchImpl: typeof fetch = safeFetch,
): Promise<ParseResult> {
  const canonicalURL = await canonicalizeUrl(rawUrl, fetchImpl);
  const host = hostOf(new URL(canonicalURL));
  const source = sourceForHost(host);
  const bare: ParseResult = { canonicalURL, source, ...emptyFields };

  if (source === "instagram" || source === "tiktok") {
    const fields = await fetchOEmbed(source, canonicalURL, fetchImpl);
    return {
      canonicalURL,
      source,
      ...tidy(fields, canonicalURL),
      title: null,
      price: null,
      currency: null,
    };
  }

  let response: Response;
  try {
    response = await fetchImpl(canonicalURL, {
      redirect: "follow",
      signal: AbortSignal.timeout(upstreamTimeoutMs),
      headers: {
        "user-agent": browserUserAgent,
        "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "accept-language": "en-US,en;q=0.9",
      },
    });
  } catch {
    return bare;
  }

  if (!response.ok) {
    await response.body?.cancel();
    return bare;
  }

  let html: string | null;
  try {
    html = await readHtml(response);
  } catch {
    return bare;
  }
  if (!html) return bare;

  try {
    return { canonicalURL, source, ...tidy(extractFields(html, host), canonicalURL) };
  } catch {
    return bare;
  }
}
