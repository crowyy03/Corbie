import { assertEquals, assertRejects, assertThrows } from "@std/assert";
import { encodeBase64 } from "@std/encoding/base64";
import {
  exchangeAuthorizationCode,
  refreshTokenAtSignIn,
  revokeRefreshToken,
} from "../supabase/functions/_shared/appleTokens.ts";
import { ApiError } from "../supabase/functions/_shared/respond.ts";

const served: { handler?: unknown } = {};
const realServe = Object.getOwnPropertyDescriptor(Deno, "serve")!;
Object.defineProperty(Deno, "serve", {
  configurable: true,
  value: (handler: unknown) => {
    served.handler = handler;
  },
});
const { authorizationCodeFrom } = await import("../supabase/functions/session/index.ts");
Object.defineProperty(Deno, "serve", realServe);

interface Recorded {
  url: string;
  form: URLSearchParams;
}

function recordingFetch(status: number, body: unknown, calls: Recorded[]): typeof fetch {
  return async (input, init) => {
    calls.push({ url: String(input), form: new URLSearchParams(String(init?.body ?? "")) });
    return await Promise.resolve(
      new Response(JSON.stringify(body), {
        status,
        headers: { "content-type": "application/json" },
      }),
    );
  };
}

async function withAppleSecrets(run: () => Promise<void>): Promise<void> {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, [
    "sign",
    "verify",
  ]);
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${encodeBase64(pkcs8)}\n-----END PRIVATE KEY-----`;
  Deno.env.set("APPLE_TEAM_ID", "735XXP9B5R");
  Deno.env.set("APPLE_KEY_ID", "5FTU34GQVH");
  Deno.env.set("APPLE_PRIVATE_KEY", pem);
  try {
    await run();
  } finally {
    Deno.env.delete("APPLE_TEAM_ID");
    Deno.env.delete("APPLE_KEY_ID");
    Deno.env.delete("APPLE_PRIVATE_KEY");
  }
}

Deno.test("the code is exchanged for a refresh token with the client secret", async () => {
  const calls: Recorded[] = [];
  const token = await exchangeAuthorizationCode(
    "code-1",
    "app.corbie",
    "secret-jwt",
    recordingFetch(200, { refresh_token: "refresh-1" }, calls),
  );
  assertEquals(token, "refresh-1");
  assertEquals(calls.length, 1);
  assertEquals(calls[0].url, "https://appleid.apple.com/auth/token");
  assertEquals(calls[0].form.get("grant_type"), "authorization_code");
  assertEquals(calls[0].form.get("code"), "code-1");
  assertEquals(calls[0].form.get("client_id"), "app.corbie");
  assertEquals(calls[0].form.get("client_secret"), "secret-jwt");
});

Deno.test("a rejected or expired code is an upstream failure", async () => {
  const calls: Recorded[] = [];
  await assertRejects(
    () =>
      exchangeAuthorizationCode(
        "stale",
        "app.corbie",
        "secret-jwt",
        recordingFetch(400, { error: "invalid_grant" }, calls),
      ),
    ApiError,
    "Apple did not accept the authorization code",
  );
});

Deno.test("revoking sends the refresh token with its hint", async () => {
  const calls: Recorded[] = [];
  await revokeRefreshToken("refresh-1", "app.corbie", "secret-jwt", recordingFetch(200, {}, calls));
  assertEquals(calls[0].url, "https://appleid.apple.com/auth/revoke");
  assertEquals(calls[0].form.get("token"), "refresh-1");
  assertEquals(calls[0].form.get("token_type_hint"), "refresh_token");
});

Deno.test("sign in without a code asks Apple for nothing", async () => {
  const calls: Recorded[] = [];
  assertEquals(await refreshTokenAtSignIn(null, recordingFetch(200, {}, calls)), null);
  assertEquals(calls.length, 0);
});

Deno.test("sign in with a code returns the refresh token built with a signed client secret", async () => {
  await withAppleSecrets(async () => {
    const calls: Recorded[] = [];
    const token = await refreshTokenAtSignIn(
      "code-2",
      recordingFetch(200, { refresh_token: "refresh-2" }, calls),
    );
    assertEquals(token, "refresh-2");
    const secret = calls[0].form.get("client_secret") ?? "";
    assertEquals(secret.split(".").length, 3);
    const header = JSON.parse(atob(secret.split(".")[0].replace(/-/g, "+").replace(/_/g, "/")));
    assertEquals(header.alg, "ES256");
    assertEquals(header.kid, "5FTU34GQVH");
  });
});

Deno.test("sign in still succeeds without a refresh token when Apple refuses", async () => {
  await withAppleSecrets(async () => {
    const calls: Recorded[] = [];
    assertEquals(
      await refreshTokenAtSignIn("code-3", recordingFetch(400, { error: "invalid_grant" }, calls)),
      null,
    );
    assertEquals(calls.length, 1);
  });
});

Deno.test("sign in still succeeds without a refresh token when the Apple key is not configured", async () => {
  Deno.env.delete("APPLE_TEAM_ID");
  const calls: Recorded[] = [];
  assertEquals(await refreshTokenAtSignIn("code-4", recordingFetch(200, {}, calls)), null);
  assertEquals(calls.length, 0);
});

Deno.test("the session body may carry an authorization code and nothing malformed", () => {
  assertEquals(authorizationCodeFrom(null), null);
  assertEquals(authorizationCodeFrom({}), null);
  assertEquals(authorizationCodeFrom({ authorizationCode: null }), null);
  assertEquals(authorizationCodeFrom({ authorizationCode: " code-5 " }), "code-5");
  for (const value of [42, "", "   ", {}, "x".repeat(4097)]) {
    const error = assertThrows(
      () => authorizationCodeFrom({ authorizationCode: value }),
      ApiError,
    ) as ApiError;
    assertEquals(error.code, "invalid_request");
  }
});
