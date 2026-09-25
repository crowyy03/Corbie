import { assertEquals, assertRejects } from "@std/assert";
import type { Environment } from "../supabase/functions/_shared/appstore.ts";
import {
  type NotificationDeps,
  processNotification,
} from "../supabase/functions/_shared/notifications.ts";
import { ApiError } from "../supabase/functions/_shared/respond.ts";
import {
  appAppleId,
  bundleId,
  day,
  hour,
  notification,
  readUnsigned,
  transaction,
  unsignedJws,
} from "./support/appStore.ts";
import { testDatabase } from "./support/database.ts";

const space = "1c2b8e3a-4d5f-4a6b-8c7d-9e0f1a2b3c4d";
const t0 = Date.now();
const database = await testDatabase();

const deps: NotificationDeps = {
  verify: readUnsigned,
  bundleId,
  appAppleId,
  store: database.store,
  now: () => new Date(t0),
};

let sequence = 0;
function uuid(): string {
  sequence += 1;
  return `notification-${sequence}`;
}

function renewed(
  environment: Environment,
  originalTransactionId: string,
  fields: { status?: number; signedDate?: number; expiresDate?: number; transactionId?: string } =
    {},
): string {
  return notification({
    type: "DID_RENEW",
    environment,
    uuid: uuid(),
    signedDate: fields.signedDate ?? t0,
    status: fields.status ?? 1,
    transaction: transaction(environment, {
      originalTransactionId,
      transactionId: fields.transactionId ?? originalTransactionId,
      appAccountToken: space,
      expiresDate: fields.expiresDate ?? t0 + 30 * day,
      signedDate: fields.signedDate ?? t0,
    }),
    renewal: { autoRenewStatus: 1, environment },
  });
}

async function spaceStatus(environment: Environment): Promise<string | undefined> {
  return (await database.store.entitlement(space, environment))?.status;
}

Deno.test("sandbox and production notifications are both accepted and kept apart", async () => {
  await database.reset();
  assertEquals(await processNotification(renewed("Production", "1000000001"), deps), {
    applied: "applied",
    notificationUUID: `notification-${sequence}`,
  });
  await processNotification(renewed("Sandbox", "2000000001", { signedDate: t0 + hour }), deps);
  assertEquals(await spaceStatus("Production"), "active");
  assertEquals(await spaceStatus("Sandbox"), "active");

  const sandboxRefund = notification({
    type: "REFUND",
    environment: "Sandbox",
    uuid: uuid(),
    signedDate: t0 + 2 * hour,
    status: 5,
    transaction: transaction("Sandbox", {
      originalTransactionId: "2000000001",
      appAccountToken: space,
      expiresDate: t0 + 30 * day,
      revocationDate: t0 + 2 * hour,
    }),
  });
  await processNotification(sandboxRefund, deps);
  assertEquals(await spaceStatus("Sandbox"), "revoked");
  assertEquals(await spaceStatus("Production"), "active");

  await processNotification(
    renewed("Production", "1000000001", { status: 2, signedDate: t0 + 3 * hour }),
    deps,
  );
  assertEquals(await spaceStatus("Production"), "expired");
  assertEquals(await spaceStatus("Sandbox"), "revoked");
});

Deno.test("a production notification must name this app's apple id, a sandbox one carries none", async () => {
  await database.reset();
  const foreign = notification({
    type: "SUBSCRIBED",
    environment: "Production",
    uuid: uuid(),
    signedDate: t0,
    status: 1,
    appAppleId: 1234,
    transaction: transaction("Production", {
      originalTransactionId: "1000000002",
      appAccountToken: space,
      expiresDate: t0 + day,
    }),
  });
  assertEquals(await processNotification(foreign, deps), {
    ignored: "notification for app 1234",
    notificationUUID: `notification-${sequence}`,
  });
  assertEquals(await database.subscription("1000000002"), null);

  const sandbox = await processNotification(renewed("Sandbox", "2000000002"), deps);
  assertEquals("applied" in sandbox, true);
});

Deno.test("another bundle, disagreeing environments and a bad signature are refused", async () => {
  await database.reset();
  const otherBundle = notification({
    type: "SUBSCRIBED",
    environment: "Production",
    bundleId: "com.example.other",
    uuid: uuid(),
    signedDate: t0,
    status: 1,
  });
  assertEquals("ignored" in await processNotification(otherBundle, deps), true);

  const mixed = notification({
    type: "SUBSCRIBED",
    environment: "Production",
    uuid: uuid(),
    signedDate: t0,
    status: 1,
    transaction: transaction("Sandbox", {
      originalTransactionId: "2000000003",
      appAccountToken: space,
      expiresDate: t0 + day,
    }),
  });
  assertEquals(await processNotification(mixed, deps), {
    ignored: "transaction is for another environment or app",
    notificationUUID: `notification-${sequence}`,
  });
  assertEquals(await database.subscription("2000000003"), null);

  await assertRejects(() => processNotification("not.a.jws", deps), ApiError);
});

Deno.test("the state comes from data.status, including grace during a renewal status change", async () => {
  const cases: [number, string][] = [
    [1, "active"],
    [2, "expired"],
    [3, "in_billing_retry"],
    [4, "in_grace_period"],
    [5, "revoked"],
  ];
  for (const [status, expected] of cases) {
    await database.reset();
    await processNotification(
      notification({
        type: "DID_CHANGE_RENEWAL_STATUS",
        subtype: "AUTO_RENEW_DISABLED",
        environment: "Production",
        uuid: uuid(),
        signedDate: t0,
        status,
        transaction: transaction("Production", {
          originalTransactionId: "1000000003",
          appAccountToken: space,
          expiresDate: t0 - day,
        }),
        renewal: { autoRenewStatus: 0, gracePeriodExpiresDate: t0 + 5 * day },
      }),
      deps,
    );
    const row = await database.subscription("1000000003");
    assertEquals(row?.status, expected, `status ${status}`);
    assertEquals(row?.auto_renew, false);
  }
  assertEquals(
    (await database.store.entitlement(space, "Production"))?.expiresAt,
    new Date(t0 - day).toISOString(),
  );
});

Deno.test("a refund of an older transaction leaves the paid period alone, a refund of the latest revokes", async () => {
  await database.reset();
  await processNotification(
    renewed("Production", "1000000004", {
      transactionId: "1000000006",
      expiresDate: t0 + 20 * day,
    }),
    deps,
  );

  const refund = (transactionId: string, expiresDate: number, signedDate: number) =>
    notification({
      type: "REFUND",
      environment: "Production",
      uuid: uuid(),
      signedDate,
      status: 1,
      transaction: transaction("Production", {
        originalTransactionId: "1000000004",
        transactionId,
        appAccountToken: space,
        expiresDate,
        revocationDate: signedDate,
      }),
    });

  assertEquals(
    await processNotification(refund("1000000005", t0 - 10 * day, t0 + hour), deps),
    { applied: "not_latest", notificationUUID: `notification-${sequence}` },
  );
  assertEquals(await spaceStatus("Production"), "active");

  await processNotification(refund("1000000006", t0 + 20 * day, t0 + 2 * hour), deps);
  assertEquals(await spaceStatus("Production"), "revoked");
});

Deno.test("a refund reversal restores only the latest transaction", async () => {
  await database.reset();
  const reversal = (transactionId: string, expiresDate: number, signedDate: number) =>
    notification({
      type: "REFUND_REVERSED",
      environment: "Production",
      uuid: uuid(),
      signedDate,
      status: 1,
      transaction: transaction("Production", {
        originalTransactionId: "1000000007",
        transactionId,
        appAccountToken: space,
        expiresDate,
      }),
    });
  await processNotification(
    notification({
      type: "REFUND",
      environment: "Production",
      uuid: uuid(),
      signedDate: t0,
      status: 5,
      transaction: transaction("Production", {
        originalTransactionId: "1000000007",
        transactionId: "1000000009",
        appAccountToken: space,
        expiresDate: t0 + 20 * day,
        revocationDate: t0,
      }),
    }),
    deps,
  );

  await processNotification(reversal("1000000008", t0 - 10 * day, t0 + hour), deps);
  assertEquals(await spaceStatus("Production"), "revoked");
  await processNotification(reversal("1000000009", t0 + 20 * day, t0 + 2 * hour), deps);
  assertEquals(await spaceStatus("Production"), "active");
  assertEquals((await database.subscription("1000000007"))?.revoked_at, null);
});

Deno.test("refund declined, consumption request and test notifications change nothing", async () => {
  await database.reset();
  await processNotification(renewed("Production", "1000000010"), deps);
  for (const type of ["REFUND_DECLINED", "CONSUMPTION_REQUEST", "TEST"]) {
    const result = await processNotification(
      notification({
        type,
        environment: "Production",
        uuid: uuid(),
        signedDate: t0 + hour,
        status: 2,
        transaction: transaction("Production", {
          originalTransactionId: "1000000010",
          appAccountToken: space,
          expiresDate: t0 - day,
        }),
      }),
      deps,
    );
    assertEquals(result, {
      ignored: `${type} changes nothing`,
      notificationUUID: `notification-${sequence}`,
    });
  }
  assertEquals(await spaceStatus("Production"), "active");
});

Deno.test("a notification without an app account token is kept against its subscription", async () => {
  await database.reset();
  const result = await processNotification(
    notification({
      type: "SUBSCRIBED",
      subtype: "INITIAL_BUY",
      environment: "Production",
      uuid: uuid(),
      signedDate: t0,
      status: 1,
      transaction: transaction("Production", {
        originalTransactionId: "1000000011",
        expiresDate: t0 + 3 * day,
        offerType: 3,
      }),
    }),
    deps,
  );
  assertEquals("applied" in result && result.applied, "applied");
  const row = await database.subscription("1000000011");
  assertEquals(row?.space_id, null);
  assertEquals(row?.status, "active");
  assertEquals(row?.offer_type, 3);
});

Deno.test("a summary notification without data is answered and dropped", async () => {
  const summary = unsignedJws({
    notificationType: "RENEWAL_EXTENSION",
    subtype: "SUMMARY",
    summary: { environment: "Production", bundleId, succeededCount: 1 },
  });
  assertEquals(await processNotification(summary, deps), {
    ignored: "RENEWAL_EXTENSION carries no subscription data",
    notificationUUID: null,
  });
});
