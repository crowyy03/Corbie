import { appleClientId } from "./appleAuth.ts";
import { buildAppleClientSecret } from "./appleClientSecret.ts";
import { ApiError } from "./respond.ts";

const tokenUrl = "https://appleid.apple.com/auth/token";
const revokeUrl = "https://appleid.apple.com/auth/revoke";
const upstreamTimeoutMs = 8000;

export async function exchangeAuthorizationCode(
  code: string,
  clientId: string,
  clientSecret: string,
  fetchImpl: typeof fetch = fetch,
): Promise<string> {
  const response = await fetchImpl(tokenUrl, {
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

export async function revokeRefreshToken(
  token: string,
  clientId: string,
  clientSecret: string,
  fetchImpl: typeof fetch = fetch,
): Promise<void> {
  const response = await fetchImpl(revokeUrl, {
    method: "POST",
    signal: AbortSignal.timeout(upstreamTimeoutMs),
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      token,
      token_type_hint: "refresh_token",
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

export async function refreshTokenAtSignIn(
  code: string | null,
  fetchImpl: typeof fetch = fetch,
): Promise<string | null> {
  if (!code) return null;
  try {
    const clientSecret = await buildAppleClientSecret();
    return await exchangeAuthorizationCode(code, appleClientId(), clientSecret, fetchImpl);
  } catch (error) {
    console.error(
      "no apple refresh token at sign in",
      error instanceof Error ? error.message : error,
    );
    return null;
  }
}
