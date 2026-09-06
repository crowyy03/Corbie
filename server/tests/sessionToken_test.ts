import { assertEquals, assertNotEquals, assertRejects } from "@std/assert";
import { decodeBase64Url, encodeBase64Url } from "@std/encoding/base64url";
import { requireAppleUser, resetJwksCache } from "../supabase/functions/_shared/appleAuth.ts";
import { requireUser } from "../supabase/functions/_shared/auth.ts";
import { ApiError } from "../supabase/functions/_shared/respond.ts";
import {
  hashAppleSubject,
  issueSessionToken,
  sessionLifetimeSeconds,
  verifySessionToken,
} from "../supabase/functions/_shared/sessionToken.ts";
import {
  appleSubject,
  lazyJwksFetch,
  makeKeyPair,
  makeToken,
  validClaims,
} from "./support/appleToken.ts";

const secret = "test-session-secret-0123456789abcdef";

function useSecret(value = secret): void {
  Deno.env.set("SESSION_SECRET", value);
}

function claimsOf(token: string): Record<string, unknown> {
  return JSON.parse(new TextDecoder().decode(decodeBase64Url(token.split(".")[1])));
}

function headerOf(token: string): Record<string, unknown> {
  return JSON.parse(new TextDecoder().decode(decodeBase64Url(token.split(".")[0])));
}

function encodeSegment(value: unknown): string {
  return encodeBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

async function signWith(
  secretValue: string,
  claims: Record<string, unknown>,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secretValue),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signingInput = `${encodeSegment({ alg: "HS256", typ: "JWT" })}.${encodeSegment(claims)}`;
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(signingInput));
  return `${signingInput}.${encodeBase64Url(new Uint8Array(signature))}`;
}

function request(token: string): Request {
  return new Request("https://corbie.test/session", {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
  });
}

Deno.test("an issued token verifies back to the hashed apple subject", async () => {
  useSecret();
  const issued = await issueSessionToken(appleSubject);

  assertEquals(await verifySessionToken(issued.token), await hashAppleSubject(appleSubject));

  const claims = claimsOf(issued.token);
  assertEquals(headerOf(issued.token).alg, "HS256");
  assertEquals(claims.iss, "corbie");
  assertNotEquals(claims.sub, appleSubject);
  assertEquals(claims.sub, await hashAppleSubject(appleSubject));
  assertEquals(claims.exp, (claims.iat as number) + sessionLifetimeSeconds);
  assertEquals(issued.expiresAt.getTime(), (claims.exp as number) * 1000);
  assertEquals(sessionLifetimeSeconds, 180 * 24 * 60 * 60);
});

Deno.test("an expired session token is rejected", async () => {
  useSecret();
  const now = Math.floor(Date.now() / 1000);
  const token = await signWith(secret, {
    iss: "corbie",
    sub: await hashAppleSubject(appleSubject),
    iat: now - sessionLifetimeSeconds - 3600,
    exp: now - 3600,
  });
  await assertRejects(() => verifySessionToken(token), ApiError, "expired");
});

Deno.test("a tampered session token is rejected", async () => {
  useSecret();
  const issued = await issueSessionToken(appleSubject);
  const parts = issued.token.split(".");

  const signature = decodeBase64Url(parts[2]);
  signature[0] ^= 0x01;
  const flipped = `${parts[0]}.${parts[1]}.${encodeBase64Url(signature)}`;
  await assertRejects(() => verifySessionToken(flipped), ApiError, "signature");

  const swapped = `${parts[0]}.${
    encodeSegment({
      ...claimsOf(issued.token),
      sub: await hashAppleSubject("001234.abcdef.9999"),
    })
  }.${parts[2]}`;
  await assertRejects(() => verifySessionToken(swapped), ApiError, "signature");

  const foreign = await signWith("another-secret-entirely", claimsOf(issued.token));
  await assertRejects(() => verifySessionToken(foreign), ApiError, "signature");
});

Deno.test("session tokens are refused while SESSION_SECRET is unset", async () => {
  useSecret();
  const issued = await issueSessionToken(appleSubject);

  Deno.env.delete("SESSION_SECRET");
  await assertRejects(() => verifySessionToken(issued.token), ApiError, "not accepted");
  await assertRejects(() => requireUser(request(issued.token)), ApiError, "not accepted");
  await assertRejects(() => issueSessionToken(appleSubject), ApiError, "SESSION_SECRET");

  useSecret();
});

Deno.test("both token kinds reach an endpoint as the same subject", async () => {
  useSecret();
  resetJwksCache();
  const pair = await makeKeyPair();
  const fetchImpl = lazyJwksFetch(pair.publicKey);
  const identityToken = await makeToken(pair.privateKey, validClaims());

  await requireUser(request(identityToken), fetchImpl);

  const issued = await issueSessionToken(appleSubject);
  await requireUser(request(issued.token), fetchImpl);
  assertEquals(await verifySessionToken(issued.token), await hashAppleSubject(appleSubject));
});

Deno.test("the session endpoint takes an apple token and refuses a session token", async () => {
  useSecret();
  resetJwksCache();
  const pair = await makeKeyPair();
  const fetchImpl = lazyJwksFetch(pair.publicKey);
  const identityToken = await makeToken(pair.privateKey, validClaims());

  assertEquals(await requireAppleUser(request(identityToken), fetchImpl), appleSubject);

  const issued = await issueSessionToken(appleSubject);
  await assertRejects(
    () => requireAppleUser(request(issued.token), fetchImpl),
    ApiError,
    "Apple identity token",
  );

  const claimingCorbie = await makeToken(pair.privateKey, validClaims({ iss: "corbie" }));
  await assertRejects(
    () => requireAppleUser(request(claimingCorbie), fetchImpl),
    ApiError,
    "Apple identity token",
  );
});
