import { encodeBase64Url } from "@std/encoding/base64url";
import { appleClientId } from "../../supabase/functions/_shared/appleAuth.ts";

export const algorithm = { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" } as const;
export const kid = "corbie-test-key";
export const appleSubject = "001234.abcdef.0001";

export async function makeKeyPair(): Promise<CryptoKeyPair> {
  return await crypto.subtle.generateKey(
    { ...algorithm, modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]) },
    true,
    ["sign", "verify"],
  ) as CryptoKeyPair;
}

export function segment(value: unknown): string {
  return encodeBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

export async function makeToken(
  key: CryptoKey,
  claims: Record<string, unknown>,
  header: Record<string, unknown> = { alg: "RS256", kid },
): Promise<string> {
  const signingInput = `${segment(header)}.${segment(claims)}`;
  const signature = await crypto.subtle.sign(
    algorithm.name,
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${encodeBase64Url(new Uint8Array(signature))}`;
}

export async function jwksFetch(publicKey: CryptoKey): Promise<typeof fetch> {
  const jwk = await crypto.subtle.exportKey("jwk", publicKey);
  const body = JSON.stringify({
    keys: [{ kty: "RSA", kid, alg: "RS256", use: "sig", n: jwk.n, e: jwk.e }],
  });
  return () =>
    Promise.resolve(new Response(body, { headers: { "content-type": "application/json" } }));
}

export function lazyJwksFetch(publicKey: CryptoKey): typeof fetch {
  let pending: Promise<typeof fetch> | null = null;
  return async (input, init) => {
    pending ??= jwksFetch(publicKey);
    return await (await pending)(input, init);
  };
}

export function validClaims(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  const now = Math.floor(Date.now() / 1000);
  return {
    iss: "https://appleid.apple.com",
    aud: appleClientId(),
    sub: appleSubject,
    iat: now,
    exp: now + 600,
    ...overrides,
  };
}
