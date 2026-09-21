import { requireUser } from "../_shared/auth.ts";
import { createInvite, databaseInviteStore } from "../_shared/invites.ts";
import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { ApiError, json, readJson, requireMethod, requireUuid, serve } from "../_shared/respond.ts";

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

  return json(await createInvite(databaseInviteStore, spaceId, shareURL), 201);
}

serve(handle);
