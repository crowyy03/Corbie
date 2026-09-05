import { assertEquals, assertRejects } from "@std/assert";
import {
  appleClientId,
  resetJwksCache,
  verifyAppleIdentityToken,
} from "../supabase/functions/_shared/appleAuth.ts";
import { ApiError } from "../supabase/functions/_shared/respond.ts";
import {
  appleSubject,
  jwksFetch,
  kid,
  lazyJwksFetch,
  makeKeyPair,
  makeToken,
  validClaims,
} from "./support/appleToken.ts";

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
    appleSubject,
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
    () => verifyAppleIdentityToken(token, lazyJwksFetch(pair.publicKey)),
    ApiError,
    "audience",
  );
});

Deno.test("a token from another issuer is rejected", async () => {
  resetJwksCache();
  const pair = await makeKeyPair();
  const token = await makeToken(pair.privateKey, validClaims({ iss: "https://evil.example.com" }));
  await assertRejects(
    () => verifyAppleIdentityToken(token, lazyJwksFetch(pair.publicKey)),
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
    () => verifyAppleIdentityToken(token, lazyJwksFetch(pair.publicKey)),
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
    () => verifyAppleIdentityToken(token, lazyJwksFetch(advertised.publicKey)),
    ApiError,
    "signature",
  );
});

Deno.test("an unsigned or reshaped token is rejected", async () => {
  resetJwksCache();
  const pair = await makeKeyPair();
  const fetchImpl = lazyJwksFetch(pair.publicKey);
  await assertRejects(() => verifyAppleIdentityToken("a.b", fetchImpl), ApiError);
  const unsigned = await makeToken(pair.privateKey, validClaims(), { alg: "none", kid });
  await assertRejects(
    () => verifyAppleIdentityToken(unsigned, fetchImpl),
    ApiError,
    "algorithm",
  );
});
