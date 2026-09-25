import { assertEquals } from "@std/assert";
import { encodeBase64 } from "@std/encoding/base64";
import { encodeBase64Url } from "@std/encoding/base64url";
import { verifyAppleJws } from "../supabase/functions/_shared/appleJws.ts";
import { appleRootCaG3Pem } from "../supabase/functions/_shared/appleRootCA.ts";
import type { Environment, TransactionInfo } from "../supabase/functions/_shared/appstore.ts";
import { AppStoreServerApi } from "../supabase/functions/_shared/appStoreServerApi.ts";
import { requireUser } from "../supabase/functions/_shared/auth.ts";
import {
  type EntitlementDeps,
  entitlementHandler,
} from "../supabase/functions/_shared/entitlementEndpoint.ts";
import { processNotification } from "../supabase/functions/_shared/notifications.ts";
import { errorResponse } from "../supabase/functions/_shared/respond.ts";
import { parseCertificate, parsePem } from "../supabase/functions/_shared/x509.ts";
import {
  appAppleId,
  appleFetch,
  type AppleRoute,
  appTransactionProof,
  bundleId,
  day,
  jsonResponse,
  notification,
  readUnsigned,
  type RecordedCall,
  testApiKey,
  transaction,
  unsignedJws,
} from "./support/appStore.ts";
import { testDatabase } from "./support/database.ts";

const spaceA = "1c2b8e3a-4d5f-4a6b-8c7d-9e0f1a2b3c4d";
const spaceB = "7a1f0c2e-3b4d-4e5f-8a6b-7c8d9e0f1a2b";
const t0 = Date.now();
const database = await testDatabase();
const { key } = await testApiKey();

function deps(overrides: Partial<EntitlementDeps> = {}): EntitlementDeps {
  return {
    verify: readUnsigned,
    bundleId,
    appAppleId,
    store: database.store,
    appStoreApi: () => null,
    authenticate: () => Promise.resolve(),
    limit: () => Promise.resolve(),
    now: () => new Date(t0),
    ...overrides,
  };
}

async function answer(
  overrides: Partial<EntitlementDeps>,
  request: Request,
): Promise<{ status: number; body: Record<string, unknown> }> {
  let response: Response;
  try {
    response = await entitlementHandler(deps(overrides))(request);
  } catch (cause) {
    response = errorResponse(cause);
  }
  return { status: response.status, body: await response.json() };
}

function withApple(routes: AppleRoute[], calls: RecordedCall[]): Partial<EntitlementDeps> {
  const fetchImpl = appleFetch(routes, calls);
  return {
    appStoreApi: (environment) =>
      new AppStoreServerApi(key, environment, fetchImpl, () => new Date(t0)),
  };
}

async function read(
  spaceId: string,
  proof: string | null,
  overrides: Partial<EntitlementDeps> = {},
): Promise<{ status: number; body: Record<string, unknown> }> {
  const headers: Record<string, string> = {};
  if (proof !== null) headers["x-app-transaction"] = proof;
  return await answer(
    overrides,
    new Request(`https://corbie.test/functions/v1/entitlement/${spaceId}`, { headers }),
  );
}

async function sync(
  body: unknown,
  proof: string | null,
  overrides: Partial<EntitlementDeps> = {},
): Promise<{ status: number; body: Record<string, unknown> }> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (proof !== null) headers["x-app-transaction"] = proof;
  return await answer(
    overrides,
    new Request("https://corbie.test/functions/v1/entitlement/sync", {
      method: "POST",
      headers,
      body: JSON.stringify(body),
    }),
  );
}

function purchase(
  environment: Environment,
  originalTransactionId: string,
  appAccountToken?: string,
): TransactionInfo {
  return transaction(environment, {
    originalTransactionId,
    appAccountToken,
    expiresDate: t0 + 30 * day,
    signedDate: t0 - day,
  });
}

async function subscribe(environment: Environment, originalTransactionId: string, space?: string) {
  await processNotification(
    notification({
      type: "SUBSCRIBED",
      environment,
      uuid: crypto.randomUUID(),
      signedDate: t0 - day,
      status: 1,
      transaction: purchase(environment, originalTransactionId, space),
    }),
    { ...deps(), now: () => new Date(t0) },
  );
}

function statuses(environment: Environment, item: Record<string, unknown>): AppleRoute {
  return (call) =>
    call.method === "GET" && call.url.includes("/inApps/v1/subscriptions/")
      ? jsonResponse({
        environment,
        bundleId,
        appAppleId: environment === "Production" ? appAppleId : undefined,
        data: [{ subscriptionGroupIdentifier: "21500000", lastTransactions: [item] }],
      })
      : null;
}

const acceptToken: AppleRoute = (call) =>
  call.method === "PUT" && call.url.endsWith("/appAccountToken") ? new Response(null) : null;

async function forgedSandboxProof(): Promise<string> {
  const root = encodeBase64(parseCertificate(parsePem(appleRootCaG3Pem)).der);
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, [
    "sign",
    "verify",
  ]) as CryptoKeyPair;
  const segment = (value: unknown) =>
    encodeBase64Url(new TextEncoder().encode(JSON.stringify(value)));
  const signingInput = `${segment({ alg: "ES256", x5c: [root, root] })}.${
    segment({ receiptType: "Sandbox", bundleId })
  }`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    pair.privateKey,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${encodeBase64Url(new Uint8Array(signature))}`;
}

Deno.test("the entitlement answers the row of the caller's environment and names it", async () => {
  await database.reset();
  await subscribe("Production", "1000000001", spaceA);

  const production = await read(spaceA, null);
  assertEquals(production.status, 200);
  assertEquals(production.body.environment, "Production");
  assertEquals(production.body.status, "active");
  assertEquals(production.body.productId, "app.corbie.monthly");
  assertEquals(production.body.expiresAt, new Date(t0 + 30 * day).toISOString());

  const testFlight = await read(spaceA, appTransactionProof({ receiptType: "Sandbox", bundleId }));
  assertEquals(testFlight.body, {
    spaceId: spaceA,
    environment: "Sandbox",
    status: "none",
    productId: null,
    expiresAt: null,
    updatedAt: null,
  });
});

Deno.test("a sandbox entitlement is never read as paid by a production build", async () => {
  await database.reset();
  await subscribe("Sandbox", "2000000001", spaceA);

  const productionProofs: [string, string | null, Partial<EntitlementDeps>][] = [
    ["no proof", null, {}],
    ["a production proof", appTransactionProof({ receiptType: "Production", bundleId }), {}],
    ["an unreadable proof", "not-a-jws", {}],
    ["a sandbox proof for another app", appTransactionProof({ receiptType: "Sandbox" }), {}],
    ["an Xcode proof", appTransactionProof({ receiptType: "Xcode", bundleId }), {}],
    ["a forged sandbox proof", await forgedSandboxProof(), { verify: verifyAppleJws }],
    [
      "an unsigned sandbox proof",
      appTransactionProof({ receiptType: "Sandbox", bundleId }),
      { verify: verifyAppleJws },
    ],
  ];
  for (const [label, proof, overrides] of productionProofs) {
    const answer = await read(spaceA, proof, overrides);
    assertEquals(answer.status, 200, label);
    assertEquals(answer.body.environment, "Production", label);
    assertEquals(answer.body.status, "none", label);
  }

  const testFlight = await read(spaceA, appTransactionProof({ receiptType: "Sandbox", bundleId }));
  assertEquals(testFlight.body.status, "active");
});

Deno.test("the entitlement needs a signed-in caller", async () => {
  const answer = await read(spaceA, null, { authenticate: (req) => requireUser(req) });
  assertEquals(answer.status, 401);
  assertEquals(answer.body.error, "unauthorized");
});

Deno.test("sync points the subscription at the new space through Set App Account Token", async () => {
  await database.reset();
  await subscribe("Production", "1000000002", spaceA);
  const bought = purchase("Production", "1000000002", spaceA);
  const calls: RecordedCall[] = [];
  const apple = withApple([
    statuses("Production", {
      originalTransactionId: "1000000002",
      status: 1,
      signedTransactionInfo: unsignedJws(bought),
      signedRenewalInfo: unsignedJws({
        appAccountToken: spaceA,
        autoRenewStatus: 1,
        environment: "Production",
      }),
    }),
    acceptToken,
  ], calls);

  const answer = await sync(
    { spaceId: spaceB, signedTransaction: unsignedJws(bought) },
    null,
    apple,
  );
  assertEquals(answer.status, 200);
  assertEquals(answer.body.spaceId, spaceB);
  assertEquals(answer.body.environment, "Production");
  assertEquals(answer.body.status, "active");
  assertEquals(answer.body.reconciled, true);

  assertEquals(calls.map((call) => `${call.method} ${call.url}`), [
    "GET https://api.storekit.apple.com/inApps/v1/subscriptions/1000000002",
    "PUT https://api.storekit.apple.com/inApps/v1/transactions/1000000002/appAccountToken",
  ]);
  assertEquals(calls[1].body, { appAccountToken: spaceB });
  assertEquals(calls.every((call) => call.authorization?.startsWith("Bearer ey")), true);

  assertEquals((await read(spaceA, null)).body.status, "none");
  const row = await database.subscription("1000000002");
  assertEquals(row?.space_id, spaceB);
  assertEquals(row?.auto_renew, true);
  assertEquals(typeof row?.checked_at, "string");
});

Deno.test("sync from a TestFlight build asks the sandbox host", async () => {
  await database.reset();
  const bought = purchase("Sandbox", "2000000002", spaceA);
  const calls: RecordedCall[] = [];
  const apple = withApple([
    statuses("Sandbox", {
      originalTransactionId: "2000000002",
      status: 1,
      signedTransactionInfo: unsignedJws(bought),
      signedRenewalInfo: unsignedJws({ appAccountToken: spaceA, environment: "Sandbox" }),
    }),
  ], calls);

  const answer = await sync(
    { spaceId: spaceA, signedTransaction: unsignedJws(bought) },
    appTransactionProof({ receiptType: "Sandbox", bundleId }),
    apple,
  );
  assertEquals(answer.body.environment, "Sandbox");
  assertEquals(answer.body.status, "active");
  assertEquals(answer.body.reconciled, true);
  assertEquals(calls.map((call) => call.url), [
    "https://api.storekit-sandbox.apple.com/inApps/v1/subscriptions/2000000002",
  ]);
  assertEquals((await read(spaceA, null)).body.status, "none");
});

Deno.test("sync without the App Store Server API applies the signed transaction itself", async () => {
  await database.reset();
  await subscribe("Production", "1000000003");
  assertEquals((await database.subscription("1000000003"))?.space_id, null);

  const answer = await sync({
    spaceId: spaceB,
    signedTransaction: unsignedJws(purchase("Production", "1000000003")),
  }, null);
  assertEquals(answer.status, 200);
  assertEquals(answer.body.status, "active");
  assertEquals(answer.body.reconciled, false);
  assertEquals((await database.subscription("1000000003"))?.space_id, spaceB);
});

Deno.test("sync falls back to the signed transaction when Apple fails", async () => {
  await database.reset();
  const calls: RecordedCall[] = [];
  const apple = withApple([() => jsonResponse({ errorCode: 5000001 }, 500)], calls);
  const answer = await sync(
    {
      spaceId: spaceA,
      signedTransaction: unsignedJws(purchase("Production", "1000000004", spaceB)),
    },
    null,
    apple,
  );
  assertEquals(answer.status, 200);
  assertEquals(answer.body.status, "active");
  assertEquals(answer.body.reconciled, false);
  assertEquals(calls.map((call) => call.method), ["GET", "PUT"]);
  assertEquals((await database.subscription("1000000004"))?.space_id, spaceA);
});

Deno.test("sync leaves the token alone when Apple already has this space", async () => {
  await database.reset();
  const bought = purchase("Production", "1000000005", spaceA);
  const calls: RecordedCall[] = [];
  const apple = withApple([
    statuses("Production", {
      originalTransactionId: "1000000005",
      status: 1,
      signedTransactionInfo: unsignedJws(bought),
      signedRenewalInfo: unsignedJws({ appAccountToken: spaceA, environment: "Production" }),
    }),
    acceptToken,
  ], calls);
  const answer = await sync(
    { spaceId: spaceA, signedTransaction: unsignedJws(bought) },
    null,
    apple,
  );
  assertEquals(answer.body.reconciled, true);
  assertEquals(calls.map((call) => call.method), ["GET"]);
});

Deno.test("sync refuses a transaction from the other environment or a malformed request", async () => {
  const sandboxPurchase = unsignedJws(purchase("Sandbox", "2000000006", spaceA));
  const mismatch = await sync({ spaceId: spaceA, signedTransaction: sandboxPurchase }, null);
  assertEquals(mismatch.status, 400);
  assertEquals(mismatch.body.error, "invalid_request");

  const noSpace = await sync({ signedTransaction: sandboxPurchase }, null);
  assertEquals(noSpace.status, 400);

  const unsigned = await sync({ spaceId: spaceA, signedTransaction: "a.b.c" }, null);
  assertEquals(unsigned.status, 401);
});
