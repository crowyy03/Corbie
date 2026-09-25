import { assert, assertEquals, assertRejects } from "@std/assert";
import { decodeBase64Url } from "@std/encoding/base64url";
import {
  AppStoreServerApi,
  AppStoreServerApiError,
  appStoreServerApiFromEnv,
  appStoreServerApiKeyFromEnv,
  buildAppStoreServerApiToken,
} from "../supabase/functions/_shared/appStoreServerApi.ts";
import { ApiError } from "../supabase/functions/_shared/respond.ts";
import {
  appleFetch,
  bundleId,
  jsonResponse,
  type RecordedCall,
  testApiKey,
} from "./support/appStore.ts";

const secretNames = ["APPSTORE_ISSUER_ID", "APPSTORE_KEY_ID", "APPSTORE_PRIVATE_KEY"];

function decodeSegment(segment: string): Record<string, unknown> {
  return JSON.parse(new TextDecoder().decode(decodeBase64Url(segment)));
}

async function withSecrets(values: Record<string, string>, run: () => Promise<void> | void) {
  for (const [name, value] of Object.entries(values)) Deno.env.set(name, value);
  try {
    await run();
  } finally {
    for (const name of secretNames) Deno.env.delete(name);
  }
}

Deno.test("the api token carries the in-app purchase key claims and verifies with that key", async () => {
  const { key, publicKey } = await testApiKey();
  const now = new Date("2026-09-25T12:00:00Z");
  const token = await buildAppStoreServerApiToken(key, now);
  const [header, claims, signature] = token.split(".");

  assertEquals(decodeSegment(header), { alg: "ES256", kid: "2X9R4HXF34", typ: "JWT" });
  const decoded = decodeSegment(claims);
  const issuedAt = now.getTime() / 1000;
  assertEquals(decoded, {
    iss: "57246542-96fe-1a63-e053-0824d011072a",
    iat: issuedAt,
    exp: decoded.exp,
    aud: "appstoreconnect-v1",
    bid: bundleId,
  });
  assert((decoded.exp as number) > issuedAt);
  assert((decoded.exp as number) - issuedAt < 3600);

  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    publicKey,
    decodeBase64Url(signature) as BufferSource,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  assertEquals(valid, true);
});

Deno.test("each call goes to its environment's host with its own method, path and body", async () => {
  const { key } = await testApiKey();
  const calls: RecordedCall[] = [];
  const fetchImpl = appleFetch([() => jsonResponse({})], calls);
  const production = new AppStoreServerApi(key, "Production", fetchImpl);
  const sandbox = new AppStoreServerApi(key, "Sandbox", fetchImpl);

  await production.getAllSubscriptionStatuses("1000000001");
  await production.getTransactionInfo("1000000002");
  await sandbox.getNotificationHistory({ startDate: 1, endDate: 2, onlyFailures: true }, "page 2");
  await sandbox.requestTestNotification();
  await sandbox.getTestNotificationStatus("token-1");
  await production.setAppAccountToken("1000000003", "7a1f0c2e-3b4d-4e5f-8a6b-7c8d9e0f1a2b");

  assertEquals(calls.map((call) => `${call.method} ${call.url}`), [
    "GET https://api.storekit.apple.com/inApps/v1/subscriptions/1000000001",
    "GET https://api.storekit.apple.com/inApps/v1/transactions/1000000002",
    "POST https://api.storekit-sandbox.apple.com/inApps/v1/notifications/history?paginationToken=page%202",
    "POST https://api.storekit-sandbox.apple.com/inApps/v1/notifications/test",
    "GET https://api.storekit-sandbox.apple.com/inApps/v1/notifications/test/token-1",
    "PUT https://api.storekit.apple.com/inApps/v1/transactions/1000000003/appAccountToken",
  ]);
  assertEquals(calls[2].body, { startDate: 1, endDate: 2, onlyFailures: true });
  assertEquals(calls[5].body, { appAccountToken: "7a1f0c2e-3b4d-4e5f-8a6b-7c8d9e0f1a2b" });
  assertEquals(calls.every((call) => call.authorization?.startsWith("Bearer ")), true);
});

Deno.test("an apple error keeps its status and error code", async () => {
  const { key } = await testApiKey();
  const api = new AppStoreServerApi(
    key,
    "Production",
    appleFetch([() => jsonResponse({ errorCode: 4040005, errorMessage: "not found" }, 404)], []),
  );
  const error = await assertRejects(
    () => api.getAllSubscriptionStatuses("1"),
    AppStoreServerApiError,
  );
  assertEquals(error.status, 404);
  assertEquals(error.errorCode, 4040005);

  const offline = new AppStoreServerApi(key, "Production", () => {
    throw new TypeError("network down");
  });
  assertEquals(
    (await assertRejects(() => offline.requestTestNotification(), AppStoreServerApiError)).status,
    0,
  );
});

Deno.test("missing secrets leave the api unconfigured instead of failing", async () => {
  await withSecrets({ APPSTORE_ISSUER_ID: "issuer", APPSTORE_KEY_ID: "key" }, () => {
    assertEquals(appStoreServerApiKeyFromEnv(), null);
    assertEquals(appStoreServerApiFromEnv()("Production"), null);
    assertEquals(appStoreServerApiFromEnv()("Sandbox"), null);
  });

  const { key } = await testApiKey();
  await withSecrets({
    APPSTORE_ISSUER_ID: key.issuerId,
    APPSTORE_KEY_ID: key.keyId,
    APPSTORE_PRIVATE_KEY: key.privateKeyPem.replace(/\n/g, "\\n"),
  }, async () => {
    const configured = appStoreServerApiFromEnv()("Sandbox");
    assertEquals(configured?.environment, "Sandbox");
    const envKey = appStoreServerApiKeyFromEnv();
    assertEquals(envKey?.bundleId, bundleId);
    assert(envKey && (await buildAppStoreServerApiToken(envKey)).split(".").length === 3);
  });
});

Deno.test("an unreadable private key is an error of the call, not of the function", async () => {
  const { key } = await testApiKey();
  const api = new AppStoreServerApi({ ...key, privateKeyPem: "garbage" }, "Production");
  const error = await assertRejects(() => api.requestTestNotification(), ApiError);
  assertEquals(error.message, "APPSTORE_PRIVATE_KEY could not be read");
});
