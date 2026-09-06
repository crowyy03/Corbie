import { requireUser } from "../_shared/auth.ts";
import { generateInviteCode } from "../_shared/inviteCode.ts";
import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { ApiError, json, readJson, requireMethod, requireUuid, serve } from "../_shared/respond.ts";
import { serviceClient } from "../_shared/supabase.ts";

const ttlMinutes = 15;
const maxAttempts = 5;

interface InviteRequest {
  spaceId?: unknown;
  shareURL?: unknown;
}

function requireShareUrl(value: unknown): string {
  if (typeof value !== "string" || value.length === 0 || value.length > 2048) {
    throw new ApiError("invalid_request", "shareURL is required");
  }
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new ApiError("invalid_request", "shareURL is not a valid URL");
  }
  if (url.protocol !== "https:") {
    throw new ApiError("invalid_request", "shareURL must use https");
  }
  const host = url.hostname.toLowerCase();
  if (host !== "icloud.com" && !host.endsWith(".icloud.com")) {
    throw new ApiError("invalid_request", "shareURL must be an iCloud share link");
  }
  return url.toString();
}

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "POST");
  await enforceRateLimit(req, "invite", buckets.invite);
  await requireUser(req);

  const body = await readJson<InviteRequest>(req);
  const spaceId = requireUuid(body.spaceId, "spaceId");
  const shareURL = requireShareUrl(body.shareURL);

  const client = serviceClient();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + ttlMinutes * 60 * 1000);

  const invalidated = await client
    .from("invites")
    .update({ expires_at: now.toISOString() })
    .eq("space_id", spaceId)
    .is("redeemed_at", null)
    .gt("expires_at", now.toISOString());
  if (invalidated.error) {
    console.error("invite invalidate failed", invalidated.error);
    throw new ApiError("internal", "Could not create an invite");
  }

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const code = generateInviteCode();
    const inserted = await client.from("invites").insert({
      code,
      space_id: spaceId,
      share_url: shareURL,
      created_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
    });
    if (!inserted.error) {
      return json({ code, expiresAt: expiresAt.toISOString() }, 201);
    }
    if (inserted.error.code !== "23505") {
      console.error("invite insert failed", inserted.error);
      throw new ApiError("internal", "Could not create an invite");
    }
  }

  throw new ApiError("internal", "Could not create an invite");
}

serve(handle);
