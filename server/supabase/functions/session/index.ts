import { requireAppleUser } from "../_shared/appleAuth.ts";
import { refreshTokenAtSignIn } from "../_shared/appleTokens.ts";
import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { ApiError, json, readJson, requireMethod, serve } from "../_shared/respond.ts";
import { issueSessionToken } from "../_shared/sessionToken.ts";

interface SessionRequest {
  authorizationCode?: unknown;
}

export function authorizationCodeFrom(body: SessionRequest | null): string | null {
  const value = body?.authorizationCode;
  if (value === undefined || value === null) return null;
  if (typeof value !== "string" || value.trim().length === 0 || value.length > 4096) {
    throw new ApiError("invalid_request", "authorizationCode is not valid");
  }
  return value.trim();
}

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "POST");
  await enforceRateLimit(req, "session", buckets.session);
  const appleSubject = await requireAppleUser(req);
  const code = authorizationCodeFrom(await readJson<SessionRequest | null>(req));

  const session = await issueSessionToken(appleSubject);
  const appleRefreshToken = await refreshTokenAtSignIn(code);
  return json({
    token: session.token,
    expiresAt: session.expiresAt.toISOString(),
    ...(appleRefreshToken ? { appleRefreshToken } : {}),
  });
}

serve(handle);
