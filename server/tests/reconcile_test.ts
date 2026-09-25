import { assertEquals, assertRejects } from "@std/assert";
import { AppStoreServerApi } from "../supabase/functions/_shared/appStoreServerApi.ts";
import {
  defaultReconcileOptions,
  type ReconcileDeps,
  reconcileSubscriptions,
} from "../supabase/functions/_shared/reconcile.ts";
import { ApiError } from "../supabase/functions/_shared/respond.ts";
import { requireServiceRole } from "../supabase/functions/_shared/serviceRoleAuth.ts";
import type { SubscriptionEvent } from "../supabase/functions/_shared/subscriptions.ts";
import {
  appAppleId,
  appleFetch,
  type AppleRoute,
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

function deps(routes: AppleRoute[] | null, calls: RecordedCall[] = []): ReconcileDeps {
  const fetchImpl = appleFetch(routes ?? [], calls);
  return {
    verify: readUnsigned,
    bundleId,
    appAppleId,
    store: database.store,
    appStoreApi: (environment) =>
      routes ? new AppStoreServerApi(key, environment, fetchImpl, () => new Date(t0)) : null,
    now: () => new Date(t0),
  };
}

function storedActive(originalTransactionId: string, expiresAt: number): SubscriptionEvent {
  return {
    environment: "Production",
    originalTransactionId,
    kind: "state",
    spaceId: spaceA,
    transactionId: originalTransactionId,
    productId: "app.corbie.monthly",
    status: "active",
    expiresAt: new Date(expiresAt).toISOString(),
    revokedAt: null,
    offerType: null,
    renewal: null,
    signedDate: new Date(t0 - 40 * day).toISOString(),
    notificationUuid: null,
    checked: false,
  };
}

Deno.test("without the api secrets reconciling reports itself unconfigured and touches nothing", async () => {
  await database.reset();
  await database.store.apply(storedActive("1000000001", t0 - day));
  const report = await reconcileSubscriptions(deps(null));
  assertEquals(report.configured, false);
  assertEquals(report.checked, 0);
  assertEquals((await database.subscription("1000000001"))?.status, "active");
});

Deno.test("a live subscription past its end is re-read from apple and moved where apple says", async () => {
  await database.reset();
  await database.store.apply(storedActive("1000000002", t0 - day));
  await database.store.apply({ ...storedActive("1000000003", t0 + 20 * day), checked: true });

  const calls: RecordedCall[] = [];
  const statuses: AppleRoute = (call) =>
    call.url.endsWith("/inApps/v1/subscriptions/1000000002")
      ? jsonResponse({
        environment: "Production",
        bundleId,
        appAppleId,
        data: [{
          lastTransactions: [{
            originalTransactionId: "1000000002",
            status: 2,
            signedTransactionInfo: unsignedJws(transaction("Production", {
              originalTransactionId: "1000000002",
              appAccountToken: spaceB,
              expiresDate: t0 - day,
            })),
            signedRenewalInfo: unsignedJws({
              appAccountToken: spaceB,
              autoRenewStatus: 0,
              environment: "Production",
            }),
          }],
        }],
      })
      : null;
  const emptyHistory: AppleRoute = (call) =>
    call.url.includes("/notifications/history") ? jsonResponse({ notificationHistory: [] }) : null;

  const report = await reconcileSubscriptions(deps([statuses, emptyHistory], calls));
  assertEquals(report.checked, 1);
  assertEquals(report.changed, 1);
  assertEquals(report.checkFailures, 0);
  assertEquals(
    calls.filter((call) => call.url.includes("/subscriptions/")).map((call) => call.url),
    ["https://api.storekit.apple.com/inApps/v1/subscriptions/1000000002"],
  );

  const row = await database.subscription("1000000002");
  assertEquals(row?.status, "expired");
  assertEquals(row?.space_id, spaceB);
  assertEquals(row?.auto_renew, false);
  assertEquals(typeof row?.checked_at, "string");
  assertEquals((await database.store.dueForCheck(10)).length, 0);
});

Deno.test("missed notifications are replayed from both environments once", async () => {
  await database.reset();
  const renewal = (environment: "Production" | "Sandbox", id: string, uuid: string) =>
    notification({
      type: "DID_RENEW",
      environment,
      uuid,
      signedDate: t0 - day,
      status: 1,
      transaction: transaction(environment, {
        originalTransactionId: id,
        appAccountToken: spaceA,
        expiresDate: t0 + 30 * day,
      }),
    });

  const calls: RecordedCall[] = [];
  const history: AppleRoute = (call) => {
    if (!call.url.includes("/notifications/history")) return null;
    if (call.url.startsWith("https://api.storekit-sandbox.apple.com")) {
      return jsonResponse({
        notificationHistory: [{ signedPayload: renewal("Sandbox", "2000000001", "s-1") }],
      });
    }
    if (call.url.includes("paginationToken=next")) {
      return jsonResponse({
        notificationHistory: [{ signedPayload: renewal("Production", "1000000005", "p-2") }],
        hasMore: false,
      });
    }
    return jsonResponse({
      notificationHistory: [{ signedPayload: renewal("Production", "1000000004", "p-1") }],
      hasMore: true,
      paginationToken: "next",
    });
  };

  const options = { ...defaultReconcileOptions, historyDays: 90, checkLimit: 0 };
  const first = await reconcileSubscriptions(deps([history], calls), options);
  assertEquals(first.replayed, { Production: 2, Sandbox: 1 });
  assertEquals(first.replayFailures, { Production: 0, Sandbox: 0 });
  assertEquals((await database.store.entitlement(spaceA, "Production"))?.status, "active");
  assertEquals((await database.store.entitlement(spaceA, "Sandbox"))?.status, "active");

  const bodies = calls.filter((call) => call.url.includes("/history")).map((call) => call.body);
  assertEquals(bodies[0], { startDate: t0 - 90 * day, endDate: t0, onlyFailures: true });
  assertEquals(bodies[2], { startDate: t0 - 29 * day, endDate: t0, onlyFailures: true });

  const updatedAt = (await database.subscription("1000000004"))?.updated_at;
  await reconcileSubscriptions(deps([history]), options);
  assertEquals((await database.subscription("1000000004"))?.updated_at, updatedAt);
});

Deno.test("reconciling by hand takes exactly the service role key", async () => {
  const request = (token?: string) =>
    new Request("https://corbie.test/functions/v1/appstore-reconcile", {
      method: "POST",
      headers: token ? { authorization: `Bearer ${token}` } : {},
    });
  await assertRejects(() => requireServiceRole(request("anything")), ApiError, "missing");

  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");
  try {
    await assertRejects(() => requireServiceRole(request()), ApiError, "Authorization");
    await assertRejects(() => requireServiceRole(request("service-role-ke")), ApiError, "service");
    await requireServiceRole(request("service-role-key"));
  } finally {
    Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
  }
});
