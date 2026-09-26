import { requireUser } from "../_shared/auth.ts";
import {
  accountDigest,
  cloudKitEnvironment,
  createInvite,
  databaseInviteStore,
  withdrawInvites,
} from "../_shared/invites.ts";
import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import {
  ApiError,
  empty,
  json,
  pathSegments,
  readJson,
  requireUuid,
  serve,
} from "../_shared/respond.ts";

interface InviteRequest {
  spaceId?: unknown;
  shareURL?: unknown;
  cloudKitEnvironment?: unknown;
  iCloudAccount?: unknown;
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

async function create(req: Request): Promise<Response> {
  const body = await readJson<InviteRequest>(req);
  const spaceId = requireUuid(body.spaceId, "spaceId");
  const shareURL = requireShareUrl(body.shareURL);
  const origin = {
    environment: cloudKitEnvironment(body.cloudKitEnvironment),
    account: await accountDigest(body.iCloudAccount),
  };
  return json(await createInvite(databaseInviteStore, spaceId, shareURL, origin), 201);
}

async function withdraw(req: Request): Promise<Response> {
  const spaceId = requireUuid(pathSegments(req, "invite")[0], "spaceId");
  await withdrawInvites(databaseInviteStore, spaceId);
  return empty(204);
}

async function handle(req: Request): Promise<Response> {
  if (req.method !== "POST" && req.method !== "DELETE") {
    throw new ApiError("invalid_request", "Use POST or DELETE for this endpoint", 405);
  }
  await enforceRateLimit(req, "invite", buckets.invite);
  await requireUser(req);
  return req.method === "POST" ? await create(req) : await withdraw(req);
}

serve(handle);
