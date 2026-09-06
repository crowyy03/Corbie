import { requireAnonId, sanitizeBatch } from "../_shared/events.ts";
import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { ApiError, empty, readJson, requireMethod, serve } from "../_shared/respond.ts";
import { serviceClient } from "../_shared/supabase.ts";

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "POST");
  await enforceRateLimit(req, "events", buckets.events);

  const anonId = requireAnonId(req.headers.get("x-anon-id"));
  const body = await readJson<unknown>(req);
  const rows = sanitizeBatch(anonId, body);
  if (rows.length === 0) return empty(202);

  const { error } = await serviceClient().from("events").insert(rows);
  if (error) {
    console.error("events insert failed", error);
    throw new ApiError("internal", "Could not store the events");
  }

  return empty(202);
}

serve(handle);
