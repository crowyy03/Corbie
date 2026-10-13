import { assertEquals } from "@std/assert";
import type { SubscriptionEvent } from "../supabase/functions/_shared/subscriptions.ts";
import { entitlementBody } from "../supabase/functions/_shared/subscriptions.ts";
import { testDatabase } from "./support/database.ts";

const spaceA = "1c2b8e3a-4d5f-4a6b-8c7d-9e0f1a2b3c4d";
const spaceB = "7a1f0c2e-3b4d-4e5f-8a6b-7c8d9e0f1a2b";
const deadSpace = "3f1f0a2c-3d3e-4f52-9a0f-8f1f0a2c3d3e";
const scripts = new URL("../scripts/", import.meta.url);
const day = 24 * 60 * 60 * 1000;

const database = await testDatabase();
const { db, store } = database;

async function script(name: string, placeholder: string, value: string) {
  const sql = await Deno.readTextFile(new URL(name, scripts));
  const result = await db.query<Record<string, unknown>>(sql.replace(placeholder, value));
  return result.rows;
}

function lookup(code: string) {
  return script("manual-premium-lookup.sql", "XXXXXX", code);
}

function grant(code: string) {
  return script("manual-premium-grant.sql", "XXXXXX", code);
}

function revoke(spaceId: string) {
  return script("manual-premium-revoke.sql", "00000000-0000-0000-0000-000000000000", spaceId);
}

async function reset() {
  await database.reset();
  await db.exec("delete from public.invites;");
  await db.exec(`
    insert into public.invites (code, space_id, share_url, created_at, expires_at, redeemed_at,
      cloudkit_environment)
    values
      ('K7M2QX', '${spaceA}', 'https://www.icloud.com/share/a', now(), now() + interval '1 hour',
        now(), 'production'),
      ('H4TQ9Z', '${spaceB}', 'https://www.icloud.com/share/b', now(), now() + interval '1 hour',
        now(), 'production'),
      ('P3RW8N', '${deadSpace}', 'https://www.icloud.com/share/c', now(), now() + interval '1 hour',
        null, 'production');
  `);
}

function monthly(spaceId: string): SubscriptionEvent {
  return {
    environment: "Production",
    originalTransactionId: "2000000777",
    kind: "state",
    spaceId,
    transactionId: "2000000777",
    productId: "app.corbie.monthly",
    status: "active",
    expiresAt: new Date(Date.now() + 30 * day).toISOString(),
    revokedAt: null,
    offerType: null,
    renewal: null,
    signedDate: new Date().toISOString(),
    notificationUuid: null,
    checked: false,
  };
}

async function count(): Promise<number> {
  const result = await db.query<{ n: number }>(
    "select count(*)::int as n from public.subscriptions",
  );
  return result.rows[0].n;
}

Deno.test("the lookup names the space behind an invite code and what it has now", async () => {
  await reset();
  const rows = await lookup(" k7m2qx ");
  assertEquals(rows.length, 1);
  assertEquals(rows[0].space_id, spaceA);
  assertEquals(rows[0].cloudkit_environment, "production");
  assertEquals(rows[0].partner_joined, true);
  assertEquals(rows[0].production_status, null);
  assertEquals((await lookup("P3RW8N"))[0].partner_joined, false);
});

Deno.test("a grant makes the space premium in Production until 2099 and the endpoint answers it", async () => {
  await reset();
  const granted = await grant("K7M2QX");
  assertEquals(granted.length, 1);
  assertEquals(granted[0].original_transaction_id, `manual_grant:${spaceA}`);

  const production = await store.entitlement(spaceA, "Production");
  assertEquals(production?.status, "active");
  assertEquals(production?.productId, "manual_grant");
  assertEquals(production?.expiresAt, "2099-12-31T12:00:00.000Z");
  assertEquals(entitlementBody(spaceA, "Production", production).status, "active");
  assertEquals(await store.entitlement(spaceA, "Sandbox"), null);
  assertEquals(await store.entitlement(spaceB, "Production"), null);
});

Deno.test("running the grant twice keeps one row, and unknown or unjoined codes grant nothing", async () => {
  await reset();
  await grant("K7M2QX");
  await grant("K7M2QX");
  assertEquals(await count(), 1);
  assertEquals(await grant("ZZZZZZ"), []);
  assertEquals(await grant("P3RW8N"), []);
  assertEquals(await count(), 1);
});

Deno.test("the daily App Store check leaves manual grants alone and still checks real ones", async () => {
  await reset();
  await grant("K7M2QX");
  await store.apply(monthly(spaceB));
  const due = await store.dueForCheck(60);
  assertEquals(due.map((key) => key.originalTransactionId), ["2000000777"]);
});

Deno.test("revoking marks the grant revoked so the app drops premium, and a grant can follow", async () => {
  await reset();
  await grant("K7M2QX");
  const revoked = await revoke(spaceA.toUpperCase());
  assertEquals(revoked.length, 1);
  assertEquals(revoked[0].status, "revoked");
  assertEquals((await store.entitlement(spaceA, "Production"))?.status, "revoked");
  assertEquals(await revoke(spaceA), []);
  assertEquals(await count(), 1);

  await grant("K7M2QX");
  assertEquals((await store.entitlement(spaceA, "Production"))?.status, "active");
});

Deno.test("a purchase made later keeps the grant first, and revoking leaves the purchase", async () => {
  await reset();
  await grant("K7M2QX");
  await store.apply(monthly(spaceA));
  assertEquals((await store.entitlement(spaceA, "Production"))?.productId, "manual_grant");
  await revoke(spaceA);
  const left = await store.entitlement(spaceA, "Production");
  assertEquals(left?.productId, "app.corbie.monthly");
  assertEquals(left?.status, "active");
});

Deno.test("the recent list shows codes made and redeemed in the last day and what each space has", async () => {
  await reset();
  await db.exec(`
    insert into public.invites (code, space_id, share_url, created_at, expires_at, redeemed_at,
      cloudkit_environment)
    values ('W6NB4J', '${spaceB}', 'https://www.icloud.com/share/d', now() - interval '2 days',
      now() - interval '2 days', now() - interval '2 days', 'production');
  `);
  await grant("K7M2QX");
  const sql = await Deno.readTextFile(new URL("manual-premium-recent.sql", scripts));
  const rows = (await db.query<Record<string, unknown>>(sql)).rows;
  assertEquals(rows.map((row) => row.code).sort(), ["H4TQ9Z", "K7M2QX"]);
  assertEquals(rows.find((row) => row.code === "K7M2QX")?.production_status, "active");
  assertEquals(rows.find((row) => row.code === "H4TQ9Z")?.production_status, null);
});

Deno.test("the list shows every manual grant and nothing else", async () => {
  await reset();
  await grant("K7M2QX");
  await grant("H4TQ9Z");
  await store.apply(monthly(spaceA));
  const sql = await Deno.readTextFile(new URL("manual-premium-list.sql", scripts));
  const listed = await db.query<Record<string, unknown>>(sql);
  assertEquals(listed.rows.map((row) => row.space_id).sort(), [spaceA, spaceB].sort());
});
