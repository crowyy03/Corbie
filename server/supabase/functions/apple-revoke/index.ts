import { appleClientId } from "../_shared/appleAuth.ts";
import { buildAppleClientSecret } from "../_shared/appleClientSecret.ts";
import { requireUser } from "../_shared/auth.ts";
import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { ApiError, empty, errorResponse, readJson, requireMethod } from "../_shared/respond.ts";

const tokenUrl = "https://appleid.apple.com/auth/token";
const revokeUrl = "https://appleid.apple.com/auth/revoke";
const upstreamTimeoutMs = 8000;

interface RevokeRequest {
  authorizationCode?: unknown;
  refreshToken?: unknown;
}

async function exchangeAuthorizationCode(
  code: string,
  clientId: string,
  clientSecret: string,
): Promise<string> {
  const response = await fetch(tokenUrl, {
    method: "POST",
    signal: AbortSignal.timeout(upstreamTimeoutMs),
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      code,
      client_id: clientId,
      client_secret: clientSecret,
    }),
  });
  const payload = await response.json().catch(() => ({})) as {
    refresh_token?: string;
    error?: string;
  };
  if (!response.ok || !payload.refresh_token) {
    console.error("apple token exchange failed", response.status, payload.error);
    throw new ApiError("upstream_failed", "Apple did not accept the authorization code");
  }
  return payload.refresh_token;
}

async function revokeToken(
  token: string,
  tokenTypeHint: string,
  clientId: string,
  clientSecret: string,
): Promise<void> {
  const response = await fetch(revokeUrl, {
    method: "POST",
    signal: AbortSignal.timeout(upstreamTimeoutMs),
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      token,
      token_type_hint: tokenTypeHint,
      client_id: clientId,
      client_secret: clientSecret,
    }),
  });
  await response.body?.cancel();
  if (!response.ok) {
    console.error("apple revoke failed", response.status);
    throw new ApiError("upstream_failed", "Apple did not accept the revoke request");
  }
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
    await revokeToken(refreshToken, "refresh_token", clientId, clientSecret);
    return empty(204);
  }

  const exchanged = await exchangeAuthorizationCode(authorizationCode!, clientId, clientSecret);
  await revokeToken(exchanged, "refresh_token", clientId, clientSecret);
  return empty(204);
}

Deno.serve(async (req) => {
  try {
    return await handle(req);
  } catch (cause) {
    return errorResponse(cause);
  }
});
