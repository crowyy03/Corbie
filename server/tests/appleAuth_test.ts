import { assertEquals, assertRejects } from "@std/assert";
import { encodeBase64Url } from "@std/encoding/base64url";
import {
  appleClientId,
  resetJwksCache,
  verifyAppleIdentityToken,
} from "../supabase/functions/_shared/appleAuth.ts";
import { ApiError } from "../supabase/functions/_shared/respond.ts";

const algorithm = { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" } as const;
const kid = "corbie-test-key";

async function makeKeyPair(): Promise<CryptoKeyPair> {
  return await crypto.subtle.generateKey(
    { ...algorithm, modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]) },
    true,
    ["sign", "verify"],
  ) as CryptoKeyPair;
}

function segment(value: unknown): string {
  return encodeBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

async function makeToken(
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

async function jwksFetch(publicKey: CryptoKey): Promise<typeof fetch> {
  const jwk = await crypto.subtle.exportKey("jwk", publicKey);
  const body = JSON.stringify({
    keys: [{ kty: "RSA", kid, alg: "RS256", use: "sig", n: jwk.n, e: jwk.e }],
  });
  return () =>
    Promise.resolve(new Response(body, { headers: { "content-type": "application/json" } }));
}

function validClaims(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  const now = Math.floor(Date.now() / 1000);
  return {
    iss: "https://appleid.apple.com",
    aud: appleClientId(),
    sub: "001234.abcdef.0001",
    iat: now,
    exp: now + 600,
    ...overrides,
  };
}

Deno.test("audience defaults to app.corbie", () => {
  Deno.env.delete("APPLE_CLIENT_ID");
  assertEquals(appleClientId(), "app.corbie");
});

Deno.test("a well formed token yields the apple subject", async () => {
  resetJwksCache();
  const pair = await makeKeyPair();
  const token = await makeToken(pair.privateKey, validClaims());
  assertEquals(
    await verifyAppleIdentityToken(token, await jwksFetch(pair.publicKey)),
    "001234.abcdef.0001",
  );
});

Deno.test("the jwks response is cached across verifications", async () => {
  resetJwksCache();
  const pair = await makeKeyPair();
  const inner = await jwksFetch(pair.publicKey);
  let calls = 0;
  const counting: typeof fetch = (input, init) => {
    calls += 1;
    return inner(input, init);
  };
  const token = await makeToken(pair.privateKey, validClaims());
  await verifyAppleIdentityToken(token, counting);
  await verifyAppleIdentityToken(token, counting);
  assertEquals(calls, 1);
});

Deno.test("a token for another audience is rejected", async () => {
  resetJwksCache();
  const pair = await makeKeyPair();
  const token = await makeToken(pair.privateKey, validClaims({ aud: "com.someone.else" }));
  await assertRejects(
    () => verifyAppleIdentityToken(token, jwksFetchSync(pair.publicKey)),
    ApiError,
    "audience",
  );
});

Deno.test("a token from another issuer is rejected", async () => {
  resetJwksCache();
  const pair = await makeKeyPair();
  const token = await makeToken(pair.privateKey, validClaims({ iss: "https://evil.example.com" }));
  await assertRejects(
    () => verifyAppleIdentityToken(token, jwksFetchSync(pair.publicKey)),
    ApiError,
    "issuer",
  );
});

Deno.test("an expired token is rejected", async () => {
  resetJwksCache();
  const pair = await makeKeyPair();
  const now = Math.floor(Date.now() / 1000);
  const token = await makeToken(pair.privateKey, validClaims({ exp: now - 3600, iat: now - 7200 }));
  await assertRejects(
    () => verifyAppleIdentityToken(token, jwksFetchSync(pair.publicKey)),
    ApiError,
    "expired",
  );
});

Deno.test("a token signed by another key is rejected", async () => {
  resetJwksCache();
  const signer = await makeKeyPair();
  const advertised = await makeKeyPair();
  const token = await makeToken(signer.privateKey, validClaims());
  await assertRejects(
    () => verifyAppleIdentityToken(token, jwksFetchSync(advertised.publicKey)),
    ApiError,
    "signature",
  );
});

Deno.test("an unsigned or reshaped token is rejected", async () => {
  resetJwksCache();
  const pair = await makeKeyPair();
  const fetchImpl = jwksFetchSync(pair.publicKey);
  await assertRejects(() => verifyAppleIdentityToken("a.b", fetchImpl), ApiError);
  const unsigned = await makeToken(pair.privateKey, validClaims(), { alg: "none", kid });
  await assertRejects(
    () => verifyAppleIdentityToken(unsigned, fetchImpl),
    ApiError,
    "algorithm",
  );
});

function jwksFetchSync(publicKey: CryptoKey): typeof fetch {
  let pending: Promise<typeof fetch> | null = null;
  return async (input, init) => {
    pending ??= jwksFetch(publicKey);
    return await (await pending)(input, init);
  };
}
