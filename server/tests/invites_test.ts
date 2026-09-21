import { assert, assertEquals, assertNotEquals, assertRejects } from "@std/assert";
import { saltedDigest } from "../supabase/functions/_shared/hash.ts";
import {
  createInvite,
  inviteLifetimeMs,
  redeemerDigest,
  redeemInvite,
} from "../supabase/functions/_shared/invites.ts";
import { clientKey } from "../supabase/functions/_shared/rateLimit.ts";
import { ApiError, type ErrorCode } from "../supabase/functions/_shared/respond.ts";
import { MemoryInviteStore } from "./support/inviteStore.ts";

const space = "1c2b8e3a-4d5f-4a6b-8c7d-9e0f1a2b3c4d";
const otherSpace = "7a1f0c2e-3b4d-4e5f-8a6b-7c8d9e0f1a2b";
const shareURL = "https://www.icloud.com/share/0abcDEF";
const phone = "3f1f0a2c-3d3e-4f52-9a0f-8f1f0a2c3d3e";
const otherPhone = "9b8c7d6e-5f4a-4b3c-8d2e-1f0a9b8c7d6e";
const start = new Date("2026-09-21T10:00:00.000Z");

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
  await createInvite(store, space, shareURL, start, codes("FYDW7C"));
  store.add({
    code: "OTHER2",
    space_id: otherSpace,
    share_url: shareURL,
    created_at: start.toISOString(),
    expires_at: minutes(15).toISOString(),
  });
  const second = await createInvite(store, space, shareURL, minutes(1), codes("JHQ6FU"));

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
  await createInvite(store, space, shareURL, minutes(5), codes("XAQ5Y9"));

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
  const created = await createInvite(store, space, shareURL, start, codes("FYDW7C", "JHQ6FU"));
  assertEquals(created.code, "JHQ6FU");
  assertEquals(store.row("FYDW7C").space_id, otherSpace);
});

Deno.test("the partner typing a replaced code hears superseded with 410, not expired", async () => {
  const store = new MemoryInviteStore();
  await createInvite(store, space, shareURL, start, codes("FYDW7C"));
  await createInvite(store, space, shareURL, minutes(1), codes("JHQ6FU"));
  await createInvite(store, space, shareURL, minutes(2), codes("XAQ5Y9"));

  for (const code of ["FYDW7C", "JHQ6FU"]) {
    assertEquals(await refusal(() => redeemInvite(store, code, "a".repeat(32), minutes(3))), {
      code: "superseded",
      status: 410,
    });
  }
  const share = await redeemInvite(store, "XAQ5Y9", "a".repeat(32), minutes(3));
  assertEquals(share, { shareURL, spaceId: space });
});

Deno.test("the same device redeeming again within fifteen minutes gets the same share", async () => {
  const store = new MemoryInviteStore();
  await createInvite(store, space, shareURL, start, codes("K7M2QX"));
  const device = "0123456789abcdef0123456789abcdef";

  const first = await redeemInvite(store, "K7M2QX", device, minutes(10));
  const killedAndRetried = await redeemInvite(store, "K7M2QX", device, minutes(24));
  const lastSecond = await redeemInvite(store, "K7M2QX", device, minutes(25));

  assertEquals(first, { shareURL, spaceId: space });
  assertEquals(killedAndRetried, first);
  assertEquals(lastSecond, first);
  assertEquals(store.row("K7M2QX").redeemed_at, minutes(10).toISOString());
  assertEquals(store.row("K7M2QX").redeemed_by, device);
});

Deno.test("another device, the same one too late, or no device id at all gets 409 redeemed", async () => {
  const store = new MemoryInviteStore();
  await createInvite(store, space, shareURL, start, codes("K7M2QX"));
  const device = "0123456789abcdef0123456789abcdef";
  await redeemInvite(store, "K7M2QX", device, minutes(1));

  const refusals = [
    await refusal(() => redeemInvite(store, "K7M2QX", "f".repeat(32), minutes(2))),
    await refusal(() => redeemInvite(store, "K7M2QX", device, new Date(minutes(16).getTime() + 1))),
    await refusal(() => redeemInvite(store, "K7M2QX", null, minutes(2))),
  ];
  for (const answer of refusals) assertEquals(answer, { code: "redeemed", status: 409 });
});

Deno.test("without a device id a code stays single use", async () => {
  const store = new MemoryInviteStore();
  await createInvite(store, space, shareURL, start, codes("K7M2QX"));
  assertEquals(await redeemInvite(store, "K7M2QX", null, minutes(1)), { shareURL, spaceId: space });
  assertEquals(store.row("K7M2QX").redeemed_by, null);
  assertEquals(await refusal(() => redeemInvite(store, "K7M2QX", null, minutes(1))), {
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

  const answer = (code: string) => refusal(() => redeemInvite(store, code, "f".repeat(32), late));
  assertEquals(await answer("ZZZZZZ"), { code: "not_found", status: 404 });
  assertEquals(await answer("SUPEXP"), { code: "superseded", status: 410 });
  assertEquals(await answer("USEEXP"), { code: "redeemed", status: 409 });
  assertEquals(await answer("EXPIRE"), { code: "expired", status: 410 });
});

Deno.test("a device that loses the claim race hears what the winner did", async () => {
  const device = "0123456789abcdef0123456789abcdef";
  const winnerAt = minutes(1).toISOString();

  const lostToAnother = new MemoryInviteStore();
  await createInvite(lostToAnother, space, shareURL, start, codes("K7M2QX"));
  lostToAnother.beforeNextClaim = () => {
    const row = lostToAnother.row("K7M2QX");
    row.redeemed_at = winnerAt;
    row.redeemed_by = "f".repeat(32);
  };
  assertEquals(await refusal(() => redeemInvite(lostToAnother, "K7M2QX", device, minutes(1))), {
    code: "redeemed",
    status: 409,
  });

  const lostToItself = new MemoryInviteStore();
  await createInvite(lostToItself, space, shareURL, start, codes("K7M2QX"));
  lostToItself.beforeNextClaim = () => {
    const row = lostToItself.row("K7M2QX");
    row.redeemed_at = winnerAt;
    row.redeemed_by = device;
  };
  assertEquals(await redeemInvite(lostToItself, "K7M2QX", device, minutes(1)), {
    shareURL,
    spaceId: space,
  });

  const replacedMeanwhile = new MemoryInviteStore();
  await createInvite(replacedMeanwhile, space, shareURL, start, codes("K7M2QX"));
  replacedMeanwhile.beforeNextClaim = () => {
    replacedMeanwhile.row("K7M2QX").superseded_at = winnerAt;
  };
  assertEquals(await refusal(() => redeemInvite(replacedMeanwhile, "K7M2QX", device, minutes(1))), {
    code: "superseded",
    status: 410,
  });
});

Deno.test("the stored redeemer is the rate limiter's salted digest, never the device id", async () => {
  const store = new MemoryInviteStore();
  await createInvite(store, space, shareURL, start, codes("K7M2QX"));

  await withSalt("test-salt", async () => {
    const redeemer = await redeemerDigest(redeemRequest({ "x-anon-id": phone }));
    await redeemInvite(store, "K7M2QX", redeemer, minutes(1));

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
