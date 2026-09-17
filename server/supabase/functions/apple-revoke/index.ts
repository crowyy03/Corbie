import { appleClientId } from "../_shared/appleAuth.ts";
import { buildAppleClientSecret } from "../_shared/appleClientSecret.ts";
import { exchangeAuthorizationCode, revokeRefreshToken } from "../_shared/appleTokens.ts";
import { requireUser } from "../_shared/auth.ts";
import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { ApiError, empty, readJson, requireMethod, serve } from "../_shared/respond.ts";

interface RevokeRequest {
  authorizationCode?: unknown;
  refreshToken?: unknown;
}

function readToken(value: unknown, field: string): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string" || value.trim().length === 0 || value.length > 4096) {
    throw new ApiError("invalid_request", `${field} is not valid`);
  }
  return value.trim();
}

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "POST");
  await enforceRateLimit(req, "apple-revoke", buckets.appleRevoke);
  await requireUser(req);

  const body = await readJson<RevokeRequest>(req);
  const authorizationCode = readToken(body.authorizationCode, "authorizationCode");
  const refreshToken = readToken(body.refreshToken, "refreshToken");
  if (!authorizationCode && !refreshToken) {
    throw new ApiError("invalid_request", "authorizationCode or refreshToken is required");
  }

  const clientId = appleClientId();
  const clientSecret = await buildAppleClientSecret();

  if (refreshToken) {
    await revokeRefreshToken(refreshToken, clientId, clientSecret);
    return empty(204);
  }

  const exchanged = await exchangeAuthorizationCode(authorizationCode!, clientId, clientSecret);
  await revokeRefreshToken(exchanged, clientId, clientSecret);
  return empty(204);
}

serve(handle);
