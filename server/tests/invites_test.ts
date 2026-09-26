import { assert, assertEquals, assertNotEquals, assertRejects } from "@std/assert";
import { saltedDigest } from "../supabase/functions/_shared/hash.ts";
import {
  accountDigest,
  cloudKitEnvironment,
  createInvite,
  inviteLifetimeMs,
  type Redeemer,
  redeemerDigest,
  redeemerOf,
  redeemInvite,
  withdrawInvites,
} from "../supabase/functions/_shared/invites.ts";
import { clientKey } from "../supabase/functions/_shared/rateLimit.ts";
import { ApiError, type ErrorCode } from "../supabase/functions/_shared/respond.ts";
import { migratedDatabase } from "./support/database.ts";
import { MemoryInviteStore } from "./support/inviteStore.ts";

const space = "1c2b8e3a-4d5f-4a6b-8c7d-9e0f1a2b3c4d";
const otherSpace = "7a1f0c2e-3b4d-4e5f-8a6b-7c8d9e0f1a2b";
const shareURL = "https://www.icloud.com/share/0abcDEF";
const phone = "3f1f0a2c-3d3e-4f52-9a0f-8f1f0a2c3d3e";
const otherPhone = "9b8c7d6e-5f4a-4b3c-8d2e-1f0a9b8c7d6e";
const start = new Date("2026-09-21T10:00:00.000Z");

const unknownOrigin = { environment: null, account: null };

function redeemerFor(id: string | null): Redeemer {
  return { device: id, environment: null, account: null };
}

function minutes(count: number, from: Date = start): Date {
  return new Date(from.getTime() + count * 60 * 1000);
}

function codes(...values: string[]): () => string {
  const queue = [...values];
  return () => {
    const next = queue.shift();
    if (!next) throw new Error("ran out of codes");
    return next;
  };
}

async function withSalt<T>(salt: string, run: () => Promise<T>): Promise<T> {
  Deno.env.set("RATE_LIMIT_SALT", salt);
  try {
    return await run();
  } finally {
    Deno.env.delete("RATE_LIMIT_SALT");
  }
}

async function refusal(run: () => Promise<unknown>): Promise<{ code: ErrorCode; status: number }> {
  const error = await assertRejects(run, ApiError);
  return { code: error.code, status: error.status };
}

function redeemRequest(headers: Record<string, string> = {}): Request {
  return new Request("https://corbie.test/functions/v1/invite-redeem/K7M2QX", { headers });
}

Deno.test("a new code supersedes the space's older live codes and leaves their expiry alone", async () => {
  const store = new MemoryInviteStore();
  await createInvite(store, space, shareURL, unknownOrigin, start, codes("FYDW7C"));
  store.add({
    code: "OTHER2",
    space_id: otherSpace,
    share_url: shareURL,
    created_at: start.toISOString(),
    expires_at: minutes(15).toISOString(),
  });
  const second = await createInvite(
    store,
    space,
    shareURL,
    unknownOrigin,
    minutes(1),
    codes("JHQ6FU"),
  );

  assertEquals(second.code, "JHQ6FU");
  assertEquals(second.expiresAt, new Date(minutes(1).getTime() + inviteLifetimeMs).toISOString());
  assertEquals(store.row("FYDW7C").superseded_at, minutes(1).toISOString());
  assertEquals(store.row("FYDW7C").expires_at, minutes(15).toISOString());
  assertEquals(store.row("JHQ6FU").superseded_at, null);
  assertEquals(store.row("OTHER2").superseded_at, null);
});

Deno.test("a used or dead code is not marked superseded", async () => {
  const store = new MemoryInviteStore();
  store.add({
    code: "USED22",
    space_id: space,
    share_url: shareURL,
    created_at: start.toISOString(),
    expires_at: minutes(15).toISOString(),
    redeemed_at: minutes(2).toISOString(),
  });
  store.add({
    code: "OLD333",
    space_id: space,
    share_url: shareURL,
    created_at: minutes(-30).toISOString(),
    expires_at: minutes(-15).toISOString(),
  });
  await createInvite(store, space, shareURL, unknownOrigin, minutes(5), codes("XAQ5Y9"));

  assertEquals(store.row("USED22").superseded_at, null);
  assertEquals(store.row("OLD333").superseded_at, null);
});

Deno.test("a code taken by another invite is drawn again", async () => {
  const store = new MemoryInviteStore();
  store.add({
    code: "FYDW7C",
    space_id: otherSpace,
    share_url: shareURL,
    created_at: start.toISOString(),
    expires_at: minutes(15).toISOString(),
  });
  const created = await createInvite(
    store,
    space,
    shareURL,
    unknownOrigin,
    start,
    codes("FYDW7C", "JHQ6FU"),
  );
  assertEquals(created.code, "JHQ6FU");
  assertEquals(store.row("FYDW7C").space_id, otherSpace);
});

Deno.test("the partner typing a replaced code hears superseded with 410, not expired", async () => {
  const store = new MemoryInviteStore();
  await createInvite(store, space, shareURL, unknownOrigin, start, codes("FYDW7C"));
  await createInvite(store, space, shareURL, unknownOrigin, minutes(1), codes("JHQ6FU"));
  await createInvite(store, space, shareURL, unknownOrigin, minutes(2), codes("XAQ5Y9"));

  for (const code of ["FYDW7C", "JHQ6FU"]) {
    assertEquals(
      await refusal(() => redeemInvite(store, code, redeemerFor("a".repeat(32)), minutes(3))),
      {
        code: "superseded",
        status: 410,
      },
    );
  }
  const share = await redeemInvite(store, "XAQ5Y9", redeemerFor("a".repeat(32)), minutes(3));
  assertEquals(share, { shareURL, spaceId: space });
});

Deno.test("the same device redeeming again within fifteen minutes gets the same share", async () => {
  const store = new MemoryInviteStore();
  await createInvite(store, space, shareURL, unknownOrigin, start, codes("K7M2QX"));
  const device = "0123456789abcdef0123456789abcdef";

  const first = await redeemInvite(store, "K7M2QX", redeemerFor(device), minutes(10));
  const killedAndRetried = await redeemInvite(store, "K7M2QX", redeemerFor(device), minutes(24));
  const lastSecond = await redeemInvite(store, "K7M2QX", redeemerFor(device), minutes(25));

  assertEquals(first, { shareURL, spaceId: space });
  assertEquals(killedAndRetried, first);
  assertEquals(lastSecond, first);
  assertEquals(store.row("K7M2QX").redeemed_at, minutes(10).toISOString());
  assertEquals(store.row("K7M2QX").redeemed_by, device);
});

Deno.test("another device, the same one too late, or no device id at all gets 409 redeemed", async () => {
  const store = new MemoryInviteStore();
  await createInvite(store, space, shareURL, unknownOrigin, start, codes("K7M2QX"));
  const device = "0123456789abcdef0123456789abcdef";
  await redeemInvite(store, "K7M2QX", redeemerFor(device), minutes(1));

  const refusals = [
    await refusal(() => redeemInvite(store, "K7M2QX", redeemerFor("f".repeat(32)), minutes(2))),
    await refusal(() =>
      redeemInvite(store, "K7M2QX", redeemerFor(device), new Date(minutes(16).getTime() + 1))
    ),
    await refusal(() => redeemInvite(store, "K7M2QX", redeemerFor(null), minutes(2))),
  ];
  for (const answer of refusals) assertEquals(answer, { code: "redeemed", status: 409 });
});

Deno.test("without a device id a code stays single use", async () => {
  const store = new MemoryInviteStore();
  await createInvite(store, space, shareURL, unknownOrigin, start, codes("K7M2QX"));
  assertEquals(await redeemInvite(store, "K7M2QX", redeemerFor(null), minutes(1)), {
    shareURL,
    spaceId: space,
  });
  assertEquals(store.row("K7M2QX").redeemed_by, null);
  assertEquals(await refusal(() => redeemInvite(store, "K7M2QX", redeemerFor(null), minutes(1))), {
    code: "redeemed",
    status: 409,
  });
});

Deno.test("checks run in order: not found, superseded, redeemed, expired", async () => {
  const store = new MemoryInviteStore();
  const late = minutes(60);
  store.add({
    code: "SUPEXP",
    space_id: space,
    share_url: shareURL,
    created_at: start.toISOString(),
    expires_at: minutes(15).toISOString(),
    superseded_at: minutes(1).toISOString(),
  });
  store.add({
    code: "USEEXP",
    space_id: space,
    share_url: shareURL,
    created_at: start.toISOString(),
    expires_at: minutes(15).toISOString(),
    redeemed_at: minutes(2).toISOString(),
    redeemed_by: "0123456789abcdef0123456789abcdef",
  });
  store.add({
    code: "EXPIRE",
    space_id: space,
    share_url: shareURL,
    created_at: start.toISOString(),
    expires_at: minutes(15).toISOString(),
  });

  const answer = (code: string) =>
    refusal(() => redeemInvite(store, code, redeemerFor("f".repeat(32)), late));
  assertEquals(await answer("ZZZZZZ"), { code: "not_found", status: 404 });
  assertEquals(await answer("SUPEXP"), { code: "superseded", status: 410 });
  assertEquals(await answer("USEEXP"), { code: "redeemed", status: 409 });
  assertEquals(await answer("EXPIRE"), { code: "expired", status: 410 });
});

Deno.test("a device that loses the claim race hears what the winner did", async () => {
  const device = "0123456789abcdef0123456789abcdef";
  const winnerAt = minutes(1).toISOString();

  const lostToAnother = new MemoryInviteStore();
  await createInvite(lostToAnother, space, shareURL, unknownOrigin, start, codes("K7M2QX"));
  lostToAnother.beforeNextClaim = () => {
    const row = lostToAnother.row("K7M2QX");
    row.redeemed_at = winnerAt;
    row.redeemed_by = "f".repeat(32);
  };
  assertEquals(
    await refusal(() => redeemInvite(lostToAnother, "K7M2QX", redeemerFor(device), minutes(1))),
    {
      code: "redeemed",
      status: 409,
    },
  );

  const lostToItself = new MemoryInviteStore();
  await createInvite(lostToItself, space, shareURL, unknownOrigin, start, codes("K7M2QX"));
  lostToItself.beforeNextClaim = () => {
    const row = lostToItself.row("K7M2QX");
    row.redeemed_at = winnerAt;
    row.redeemed_by = device;
  };
  assertEquals(await redeemInvite(lostToItself, "K7M2QX", redeemerFor(device), minutes(1)), {
    shareURL,
    spaceId: space,
  });

  const replacedMeanwhile = new MemoryInviteStore();
  await createInvite(replacedMeanwhile, space, shareURL, unknownOrigin, start, codes("K7M2QX"));
  replacedMeanwhile.beforeNextClaim = () => {
    replacedMeanwhile.row("K7M2QX").superseded_at = winnerAt;
  };
  assertEquals(
    await refusal(() => redeemInvite(replacedMeanwhile, "K7M2QX", redeemerFor(device), minutes(1))),
    {
      code: "superseded",
      status: 410,
    },
  );
});

Deno.test("the stored redeemer is the rate limiter's salted digest, never the device id", async () => {
  const store = new MemoryInviteStore();
  await createInvite(store, space, shareURL, unknownOrigin, start, codes("K7M2QX"));

  await withSalt("test-salt", async () => {
    const redeemer = await redeemerDigest(redeemRequest({ "x-anon-id": phone }));
    await redeemInvite(store, "K7M2QX", redeemerFor(redeemer), minutes(1));

    const stored = store.row("K7M2QX").redeemed_by ?? "";
    assert(/^[0-9a-f]{32}$/.test(stored), stored);
    assertEquals(stored.includes(phone), false);
    assertEquals(stored.includes(phone.slice(0, 8)), false);
    assertEquals(stored, await saltedDigest(phone));
    assertEquals(await clientKey(redeemRequest({ "x-anon-id": phone })), `anon:${stored}`);
    assertEquals(
      await redeemerDigest(redeemRequest({ "x-anon-id": ` ${phone.toUpperCase()} ` })),
      stored,
    );
    assertNotEquals(await redeemerDigest(redeemRequest({ "x-anon-id": otherPhone })), stored);
  });

  const resalted = await withSalt(
    "other-salt",
    () => redeemerDigest(redeemRequest({ "x-anon-id": phone })),
  );
  assertNotEquals(resalted, store.row("K7M2QX").redeemed_by);
});

Deno.test("the migration check lets a digest into redeemed_by and keeps a raw device id out", async () => {
  const migration = await Deno.readTextFile(
    new URL(
      "../supabase/migrations/0008_invite_supersede_and_redeemer.sql",
      import.meta.url,
    ),
  );
  const pattern = migration.match(/redeemed_by ~ '([^']+)'/)?.[1];
  assert(pattern, "the migration carries no check on redeemed_by");
  const allowed = new RegExp(pattern);
  const digest = await withSalt("test-salt", () => saltedDigest(phone));
  assertEquals(allowed.test(digest), true);
  assertEquals(allowed.test(phone), false);
});

Deno.test("a missing device id keeps the old behaviour and a malformed one is refused", async () => {
  await withSalt("test-salt", async () => {
    assertEquals(await redeemerDigest(redeemRequest()), null);
    assertEquals(await redeemerDigest(redeemRequest({ "x-anon-id": "  " })), null);
    assertEquals(
      await refusal(() => redeemerDigest(redeemRequest({ "x-anon-id": "not-a-uuid" }))),
      { code: "invalid_request", status: 400 },
    );
  });
});

const fingerprint = "c".repeat(64);
const otherFingerprint = "d".repeat(64);

Deno.test("a code from the other iCloud environment is refused before it burns", async () => {
  const store = new MemoryInviteStore();
  const origin = { environment: "development" as const, account: null };
  await createInvite(store, space, shareURL, origin, start, codes("K7M2QX"));
  const production = { device: "a".repeat(32), environment: "production" as const, account: null };

  assertEquals(await refusal(() => redeemInvite(store, "K7M2QX", production, minutes(1))), {
    code: "environment_mismatch",
    status: 409,
  });
  assertEquals(store.row("K7M2QX").redeemed_at, null);

  const development = { ...production, environment: "development" as const };
  assertEquals(await redeemInvite(store, "K7M2QX", development, minutes(2)), {
    shareURL,
    spaceId: space,
  });
});

Deno.test("an old client on either side skips the environment check", async () => {
  const oldOwner = new MemoryInviteStore();
  await createInvite(oldOwner, space, shareURL, unknownOrigin, start, codes("K7M2QX"));
  const production = { device: null, environment: "production" as const, account: null };
  assertEquals(await redeemInvite(oldOwner, "K7M2QX", production, minutes(1)), {
    shareURL,
    spaceId: space,
  });

  const oldJoiner = new MemoryInviteStore();
  const origin = { environment: "development" as const, account: null };
  await createInvite(oldJoiner, space, shareURL, origin, start, codes("K7M2QX"));
  assertEquals(await redeemInvite(oldJoiner, "K7M2QX", redeemerFor(null), minutes(1)), {
    shareURL,
    spaceId: space,
  });
});

Deno.test("the owner's own iCloud account is told so, before the code burns and on a replay", async () => {
  const store = new MemoryInviteStore();
  const owner = await withSalt("test-salt", () => accountDigest(fingerprint));
  const partner = await withSalt("test-salt", () => accountDigest(otherFingerprint));
  await createInvite(
    store,
    space,
    shareURL,
    { environment: null, account: owner },
    start,
    codes("K7M2QX"),
  );

  const sameAccount = { device: "a".repeat(32), environment: null, account: owner };
  assertEquals(await refusal(() => redeemInvite(store, "K7M2QX", sameAccount, minutes(1))), {
    code: "same_icloud_account",
    status: 409,
  });
  assertEquals(store.row("K7M2QX").redeemed_at, null);

  const other = { ...sameAccount, account: partner };
  assertEquals(await redeemInvite(store, "K7M2QX", other, minutes(2)), {
    shareURL,
    spaceId: space,
  });

  store.row("K7M2QX").owner_account = partner;
  assertEquals(await refusal(() => redeemInvite(store, "K7M2QX", other, minutes(3))), {
    code: "same_icloud_account",
    status: 409,
  });
});

Deno.test("withdrawing a space's invites expires only its live codes", async () => {
  const store = new MemoryInviteStore();
  await createInvite(store, space, shareURL, unknownOrigin, start, codes("LIVE22"));
  store.add({
    code: "USED22",
    space_id: space,
    share_url: shareURL,
    created_at: start.toISOString(),
    expires_at: minutes(15).toISOString(),
    redeemed_at: minutes(1).toISOString(),
  });
  store.add({
    code: "OTHER2",
    space_id: otherSpace,
    share_url: shareURL,
    created_at: start.toISOString(),
    expires_at: minutes(15).toISOString(),
  });

  await withdrawInvites(store, space, minutes(2));

  assertEquals(store.row("LIVE22").expires_at, minutes(2).toISOString());
  assertEquals(store.row("USED22").expires_at, minutes(15).toISOString());
  assertEquals(store.row("OTHER2").expires_at, minutes(15).toISOString());
  assertEquals(await refusal(() => redeemInvite(store, "LIVE22", redeemerFor(null), minutes(3))), {
    code: "expired",
    status: 410,
  });
});

Deno.test("the redeem headers are read, checked and the account is stored salted", async () => {
  await withSalt("test-salt", async () => {
    const redeemer = await redeemerOf(redeemRequest({
      "x-anon-id": phone,
      "x-cloudkit-environment": "production",
      "x-icloud-account": fingerprint.toUpperCase(),
    }));
    assertEquals(redeemer.device, await saltedDigest(phone));
    assertEquals(redeemer.environment, "production");
    assertEquals(redeemer.account, await saltedDigest(fingerprint));

    assertEquals(await redeemerOf(redeemRequest()), {
      device: null,
      environment: null,
      account: null,
    });
    assertEquals(
      await refusal(() => redeemerOf(redeemRequest({ "x-cloudkit-environment": "staging" }))),
      { code: "invalid_request", status: 400 },
    );
    assertEquals(
      await refusal(() => redeemerOf(redeemRequest({ "x-icloud-account": "_abc" }))),
      { code: "invalid_request", status: 400 },
    );
  });
});

Deno.test("the invite body's environment and account are checked the same way", async () => {
  assertEquals(cloudKitEnvironment(undefined), null);
  assertEquals(cloudKitEnvironment("development"), "development");
  assertEquals(await refusal(() => Promise.resolve().then(() => cloudKitEnvironment("Prod"))), {
    code: "invalid_request",
    status: 400,
  });
  assertEquals(await accountDigest(undefined), null);
  assertEquals(await refusal(() => accountDigest(fingerprint.slice(1))), {
    code: "invalid_request",
    status: 400,
  });
});

Deno.test("migration 0010 lets a known environment and a digest in and keeps anything else out", async () => {
  const db = await migratedDatabase();
  const insert = (code: string, environment: string | null, account: string | null) =>
    db.query(
      `insert into public.invites (code, space_id, share_url, expires_at, cloudkit_environment, owner_account)
       values ($1, $2, $3, now() + interval '15 minutes', $4, $5)`,
      [code, space, shareURL, environment, account],
    );
  const digest = await withSalt("test-salt", () => saltedDigest(fingerprint));

  await insert("AAAAAA", "production", digest);
  await insert("BBBBBB", null, null);
  await assertRejects(() => insert("CCCCCC", "staging", null));
  await assertRejects(() => insert("DDDDDD", "development", fingerprint));
  await db.close();
});
