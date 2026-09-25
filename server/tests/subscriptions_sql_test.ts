import { assertEquals } from "@std/assert";
import type { SubscriptionEvent } from "../supabase/functions/_shared/subscriptions.ts";
import { migratedDatabase, testDatabase } from "./support/database.ts";

const spaceA = "1c2b8e3a-4d5f-4a6b-8c7d-9e0f1a2b3c4d";
const spaceB = "7a1f0c2e-3b4d-4e5f-8a6b-7c8d9e0f1a2b";
const hour = 60 * 60 * 1000;
const t0 = Date.now();

function at(offsetHours: number): string {
  return new Date(t0 + offsetHours * hour).toISOString();
}

function event(fields: Partial<SubscriptionEvent> & { originalTransactionId: string }) {
  return {
    environment: "Production",
    kind: "state",
    spaceId: spaceA,
    transactionId: fields.originalTransactionId,
    productId: "app.corbie.monthly",
    status: "active",
    expiresAt: at(24 * 30),
    revokedAt: null,
    offerType: null,
    renewal: null,
    signedDate: at(0),
    notificationUuid: null,
    checked: false,
    ...fields,
  } as SubscriptionEvent;
}

const database = await testDatabase();
const { store } = database;

Deno.test("the old per-space rows move into one row per subscription and the old table is gone", async () => {
  const db = await migratedDatabase(async (name, db) => {
    if (!name.startsWith("0009")) return;
    await db.exec(`
      insert into public.entitlements
        (space_id, original_transaction_id, product_id, status, expires_at, environment,
         signed_date, notification_uuid)
      values
        ('${spaceA}', '2000000001', 'app.corbie.monthly', 'in_grace_period',
         '2026-10-01T00:00:00Z', 'Sandbox', '2026-09-20T00:00:00Z', 'n-1'),
        ('${spaceB}', '1000000002', 'app.corbie.yearly', 'active',
         '2027-09-01T00:00:00Z', 'Production', '2026-09-01T00:00:00Z', 'n-2'),
        ('3f1f0a2c-3d3e-4f52-9a0f-8f1f0a2c3d3e', null, null, 'none', null, 'Production', null, null);
    `);
  });

  const rows = await db.query<Record<string, unknown>>(
    "select environment, original_transaction_id, space_id, status, grace_period_expires_at, " +
      "last_notification_uuid from public.subscriptions order by original_transaction_id",
  );
  assertEquals(rows.rows.map((row) => row.original_transaction_id), ["1000000002", "2000000001"]);
  assertEquals(rows.rows[1].environment, "Sandbox");
  assertEquals(rows.rows[1].space_id, spaceA);
  assertEquals(
    (rows.rows[1].grace_period_expires_at as Date).toISOString(),
    "2026-10-01T00:00:00.000Z",
  );
  assertEquals(rows.rows[1].last_notification_uuid, "n-1");
  assertEquals(rows.rows[0].grace_period_expires_at, null);

  const sandbox = await db.query<Record<string, unknown>>(
    "select status, expires_at from public.space_entitlement($1, 'Sandbox')",
    [spaceA],
  );
  assertEquals(sandbox.rows[0].status, "in_grace_period");
  const production = await db.query("select * from public.space_entitlement($1, 'Production')", [
    spaceA,
  ]);
  assertEquals(production.rows.length, 0);

  const leftovers = await db.query<{ name: string | null }>(
    "select to_regclass('public.entitlements')::text as name " +
      "union all select to_regprocedure('public.entitlement_apply(uuid, text, text, text, " +
      "timestamptz, text, text, timestamptz, text)')::text",
  );
  assertEquals(leftovers.rows.map((row) => row.name), [null, null]);
  await db.close();
});

Deno.test("anon and authenticated can read or call nothing new", async () => {
  const privileges = await database.db.query<Record<string, boolean>>(`
    select
      has_table_privilege('anon', 'public.subscriptions', 'select') as anon_table,
      has_table_privilege('authenticated', 'public.subscriptions', 'select') as user_table,
      has_table_privilege('anon', 'public.space_entitlements', 'select') as anon_view,
      has_function_privilege('anon', 'public.space_entitlement(uuid, text)', 'execute') as anon_read,
      has_function_privilege('authenticated',
        'public.subscription_apply(text, text, text, uuid, text, text, text, timestamptz, ' ||
        'timestamptz, smallint, boolean, boolean, timestamptz, timestamptz, text, boolean)',
        'execute') as user_write,
      has_function_privilege('service_role', 'public.space_entitlement(uuid, text)', 'execute')
        as service_read
  `);
  assertEquals(privileges.rows[0], {
    anon_table: false,
    user_table: false,
    anon_view: false,
    anon_read: false,
    user_write: false,
    service_read: true,
  });
});

Deno.test("a space stays paid while either of its two subscriptions is", async () => {
  await database.reset();
  await store.apply(event({ originalTransactionId: "1000000001", expiresAt: at(24 * 20) }));
  await store.apply(event({ originalTransactionId: "1000000002", expiresAt: at(24 * 300) }));
  assertEquals((await store.entitlement(spaceA, "Production"))?.expiresAt, at(24 * 300));

  await store.apply(event({
    originalTransactionId: "1000000002",
    status: "expired",
    expiresAt: at(-1),
    signedDate: at(1),
  }));
  const partner = await store.entitlement(spaceA, "Production");
  assertEquals(partner?.status, "active");
  assertEquals(partner?.expiresAt, at(24 * 20));

  await store.apply(event({
    originalTransactionId: "1000000001",
    status: "expired",
    expiresAt: at(-2),
    signedDate: at(2),
  }));
  assertEquals((await store.entitlement(spaceA, "Production"))?.status, "expired");
});

Deno.test("grace and billing retry report the grace end, a paid period its own end", async () => {
  await database.reset();
  await store.apply(event({
    originalTransactionId: "1000000003",
    status: "in_grace_period",
    expiresAt: at(-5),
    renewal: { autoRenew: true, gracePeriodExpiresAt: at(24 * 6) },
  }));
  assertEquals((await store.entitlement(spaceA, "Production"))?.expiresAt, at(24 * 6));

  await store.apply(event({
    originalTransactionId: "1000000003",
    status: "active",
    expiresAt: at(24 * 30),
    renewal: { autoRenew: true, gracePeriodExpiresAt: null },
    signedDate: at(1),
  }));
  assertEquals((await store.entitlement(spaceA, "Production"))?.expiresAt, at(24 * 30));
});

Deno.test("the two environments of one space never mix", async () => {
  await database.reset();
  await store.apply(event({ environment: "Sandbox", originalTransactionId: "2000000001" }));
  assertEquals(await store.entitlement(spaceA, "Production"), null);
  assertEquals((await store.entitlement(spaceA, "Sandbox"))?.status, "active");

  await store.apply(event({ originalTransactionId: "2000000001", status: "expired" }));
  assertEquals((await store.entitlement(spaceA, "Sandbox"))?.status, "active");
  assertEquals((await store.entitlement(spaceA, "Production"))?.status, "expired");
});

Deno.test("a repeated uuid and an older signing time change nothing", async () => {
  await database.reset();
  const renewed = event({
    originalTransactionId: "1000000004",
    notificationUuid: "uuid-renew",
    signedDate: at(5),
  });
  assertEquals(await store.apply(renewed), "applied");
  assertEquals(await store.apply({ ...renewed, status: "expired" }), "duplicate");
  assertEquals(
    await store.apply(event({
      originalTransactionId: "1000000004",
      status: "expired",
      notificationUuid: "uuid-older",
      signedDate: at(4),
    })),
    "stale",
  );
  assertEquals((await database.subscription("1000000004"))?.status, "active");
});

Deno.test("a revocation counts only for the subscription's latest transaction", async () => {
  await database.reset();
  await store.apply(event({
    originalTransactionId: "1000000005",
    transactionId: "1000000007",
    expiresAt: at(24 * 30),
    signedDate: at(0),
  }));

  const olderRefund = event({
    originalTransactionId: "1000000005",
    kind: "revocation",
    transactionId: "1000000006",
    status: "revoked",
    expiresAt: at(-24),
    revokedAt: at(1),
    signedDate: at(1),
  });
  assertEquals(await store.apply(olderRefund), "not_latest");
  assertEquals((await store.entitlement(spaceA, "Production"))?.status, "active");

  const latestRefund = {
    ...olderRefund,
    transactionId: "1000000007",
    expiresAt: at(24 * 30),
    signedDate: at(2),
  };
  assertEquals(await store.apply(latestRefund), "applied");
  const revoked = await database.subscription("1000000005");
  assertEquals(revoked?.status, "revoked");
  assertEquals(revoked?.revoked_at, at(1));

  const olderReversal = { ...olderRefund, kind: "reversal" as const, status: "active" as const };
  assertEquals(
    await store.apply({ ...olderReversal, revokedAt: null, signedDate: at(3) }),
    "not_latest",
  );
  assertEquals((await database.subscription("1000000005"))?.status, "revoked");

  assertEquals(
    await store.apply({
      ...latestRefund,
      kind: "reversal",
      status: "active",
      revokedAt: null,
      signedDate: at(4),
    }),
    "applied",
  );
  assertEquals((await database.subscription("1000000005"))?.status, "active");
});

Deno.test("a subscription without a space is linked by the first token and moved only by newer ones", async () => {
  await database.reset();
  await store.apply(event({ originalTransactionId: "1000000008", spaceId: null }));
  assertEquals(await store.entitlement(spaceA, "Production"), null);

  assertEquals(
    await store.apply(event({
      originalTransactionId: "1000000008",
      spaceId: spaceA,
      signedDate: at(-10),
      notificationUuid: "late-with-token",
    })),
    "linked",
  );
  assertEquals((await store.entitlement(spaceA, "Production"))?.status, "active");

  await store.apply(event({
    originalTransactionId: "1000000008",
    spaceId: spaceB,
    signedDate: at(-11),
  }));
  assertEquals((await database.subscription("1000000008"))?.space_id, spaceA);

  await store.apply(
    event({ originalTransactionId: "1000000008", spaceId: spaceB, signedDate: at(1) }),
  );
  assertEquals((await database.subscription("1000000008"))?.space_id, spaceB);
  assertEquals(await store.entitlement(spaceA, "Production"), null);
});

Deno.test("an explicit link moves the subscription and outranks older tokens", async () => {
  await database.reset();
  await store.apply(event({ originalTransactionId: "1000000009", signedDate: at(-1) }));
  const key = { environment: "Production" as const, originalTransactionId: "1000000009" };
  assertEquals(await store.linkSpace(key, spaceB), true);
  assertEquals((await database.subscription("1000000009"))?.space_id, spaceB);

  await store.apply(event({ originalTransactionId: "1000000009", signedDate: at(-0.5) }));
  assertEquals((await database.subscription("1000000009"))?.space_id, spaceB);
  assertEquals(
    await store.linkSpace({ ...key, originalTransactionId: "does-not-exist" }, spaceB),
    false,
  );
});

Deno.test("due checks pick live subscriptions that are unchecked, past their end or retrying", async () => {
  await database.reset();
  await store.apply(event({ originalTransactionId: "fresh", checked: true }));
  await store.apply(event({ originalTransactionId: "unchecked" }));
  await store.apply(event({ originalTransactionId: "overdue", expiresAt: at(-1), checked: true }));
  await store.apply(event({
    originalTransactionId: "retrying",
    status: "in_billing_retry",
    expiresAt: at(-100),
    checked: true,
  }));
  await store.apply(event({ originalTransactionId: "gone", status: "expired", expiresAt: at(-1) }));

  const due = (await store.dueForCheck(10)).map((key) => key.originalTransactionId).sort();
  assertEquals(due, ["overdue", "retrying", "unchecked"]);
  assertEquals((await store.dueForCheck(1)).length, 1);
});
