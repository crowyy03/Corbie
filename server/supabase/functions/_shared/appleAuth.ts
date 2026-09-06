import { assertClaims, parseJwt } from "./jwt.ts";
import { ApiError, bearerToken } from "./respond.ts";
import { isSessionToken } from "./sessionToken.ts";

const jwksUrl = "https://appleid.apple.com/auth/keys";
const issuer = "https://appleid.apple.com";
const jwksTtlMs = 60 * 60 * 1000;
const label = "Identity token";

interface AppleJwk {
  kty: string;
  kid: string;
  alg: string;
  n: string;
  e: string;
  use?: string;
}

interface JwksCache {
  keys: AppleJwk[];
  fetchedAt: number;
}

let cache: JwksCache | null = null;

export function resetJwksCache(): void {
  cache = null;
}

export function appleClientId(): string {
  return Deno.env.get("APPLE_CLIENT_ID") ?? "app.corbie";
}

async function loadKeys(fetchImpl: typeof fetch, force: boolean): Promise<AppleJwk[]> {
  const fresh = cache && Date.now() - cache.fetchedAt < jwksTtlMs;
  if (fresh && !force) return cache!.keys;

  let response: Response;
  try {
    response = await fetchImpl(jwksUrl, { signal: AbortSignal.timeout(5000) });
  } catch {
    if (cache) return cache.keys;
    throw new ApiError("upstream_failed", "Apple keys are unavailable");
  }
  if (!response.ok) {
    if (cache) return cache.keys;
    throw new ApiError("upstream_failed", "Apple keys are unavailable");
  }
  const body = await response.json() as { keys?: AppleJwk[] };
  const keys = body.keys ?? [];
  if (keys.length === 0) throw new ApiError("upstream_failed", "Apple keys are unavailable");
  cache = { keys, fetchedAt: Date.now() };
  return keys;
}

async function verifySignature(
  key: AppleJwk,
  signingInput: string,
  signature: Uint8Array,
): Promise<boolean> {
  const publicKey = await crypto.subtle.importKey(
    "jwk",
    { kty: key.kty, n: key.n, e: key.e, alg: "RS256", ext: true },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  return await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    publicKey,
    signature as BufferSource,
    new TextEncoder().encode(signingInput),
  );
}

export async function verifyAppleIdentityToken(
  token: string,
  fetchImpl: typeof fetch = fetch,
): Promise<string> {
  const { header, claims, signingInput, signature } = parseJwt(token, label);
  if (header.alg !== "RS256") throw new ApiError("unauthorized", "Unsupported token algorithm");
  const kid = typeof header.kid === "string" ? header.kid : null;
  if (!kid) throw new ApiError("unauthorized", `${label} is malformed`);

  let keys = await loadKeys(fetchImpl, false);
  let key = keys.find((candidate) => candidate.kid === kid);
  if (!key) {
    keys = await loadKeys(fetchImpl, true);
    key = keys.find((candidate) => candidate.kid === kid);
  }
  if (!key) throw new ApiError("unauthorized", `${label} key is unknown`);

  const valid = await verifySignature(key, signingInput, signature);
  if (!valid) throw new ApiError("unauthorized", `${label} signature is invalid`);

  const expected = appleClientId();
  const audience = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!audience.includes(expected)) {
    throw new ApiError("unauthorized", "Identity token audience is wrong");
  }

  return assertClaims(claims, { issuer, label });
}

export async function requireAppleUser(
  req: Request,
  fetchImpl: typeof fetch = fetch,
): Promise<string> {
  const token = bearerToken(req);
  if (isSessionToken(token)) {
    throw new ApiError("unauthorized", "This endpoint needs an Apple identity token");
  }
  return await verifyAppleIdentityToken(token, fetchImpl);
}
