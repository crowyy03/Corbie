import { assertEquals } from "@std/assert";
import {
  expiresAtOf,
  mapNotificationToStatus,
  matchesBundle,
  normalizeEnvironment,
  payerHash,
  signedDateOf,
} from "../supabase/functions/_shared/appstore.ts";

const now = Date.UTC(2026, 8, 5, 10, 0, 0);
const future = now + 30 * 24 * 60 * 60 * 1000;
const past = now - 24 * 60 * 60 * 1000;

Deno.test("renewal events with a future expiry are active", () => {
  for (const type of ["SUBSCRIBED", "DID_RENEW", "DID_CHANGE_RENEWAL_STATUS", "OFFER_REDEEMED"]) {
    assertEquals(
      mapNotificationToStatus(type, undefined, { expiresDate: future }, {}, now),
      "active",
      type,
    );
  }
});

Deno.test("a renewal event whose expiry already passed is expired", () => {
  assertEquals(
    mapNotificationToStatus("DID_RENEW", undefined, { expiresDate: past }, {}, now),
    "expired",
  );
});

Deno.test("failed renewal inside the grace window is grace", () => {
  assertEquals(
    mapNotificationToStatus(
      "DID_FAIL_TO_RENEW",
      "GRACE_PERIOD",
      { expiresDate: past },
      { gracePeriodExpiresDate: future },
      now,
    ),
    "grace",
  );
});

Deno.test("failed renewal without a grace window is expired", () => {
  assertEquals(
    mapNotificationToStatus("DID_FAIL_TO_RENEW", undefined, { expiresDate: past }, {}, now),
    "expired",
  );
  assertEquals(
    mapNotificationToStatus(
      "DID_FAIL_TO_RENEW",
      "GRACE_PERIOD",
      { expiresDate: past },
      { gracePeriodExpiresDate: past },
      now,
    ),
    "expired",
  );
});

Deno.test("expiry events are expired", () => {
  assertEquals(mapNotificationToStatus("EXPIRED", "VOLUNTARY", {}, {}, now), "expired");
  assertEquals(mapNotificationToStatus("GRACE_PERIOD_EXPIRED", undefined, {}, {}, now), "expired");
});

Deno.test("refund and revoke are revoked", () => {
  assertEquals(
    mapNotificationToStatus("REFUND", undefined, { expiresDate: future }, {}, now),
    "revoked",
  );
  assertEquals(
    mapNotificationToStatus("REVOKE", undefined, { expiresDate: future }, {}, now),
    "revoked",
  );
  assertEquals(
    mapNotificationToStatus(
      "DID_RENEW",
      undefined,
      { expiresDate: future, revocationDate: past },
      {},
      now,
    ),
    "revoked",
  );
});

Deno.test("an unknown notification type falls back to the transaction expiry", () => {
  assertEquals(
    mapNotificationToStatus("TEST", undefined, { expiresDate: future }, {}, now),
    "active",
  );
  assertEquals(
    mapNotificationToStatus("TEST", undefined, { expiresDate: past }, {}, now),
    "expired",
  );
  assertEquals(mapNotificationToStatus("TEST", undefined, {}, {}, now), "none");
});

Deno.test("grace status reports the grace expiry, other statuses the transaction expiry", () => {
  assertEquals(
    expiresAtOf("grace", { expiresDate: past }, { gracePeriodExpiresDate: future }),
    new Date(future).toISOString(),
  );
  assertEquals(
    expiresAtOf("active", { expiresDate: future }, { gracePeriodExpiresDate: past }),
    new Date(future).toISOString(),
  );
  assertEquals(expiresAtOf("expired", {}, {}), null);
});

Deno.test("environment is accepted only in the two spellings Apple uses", () => {
  assertEquals(normalizeEnvironment("Sandbox"), "Sandbox");
  assertEquals(normalizeEnvironment("Production"), "Production");
  assertEquals(normalizeEnvironment("production"), null);
  assertEquals(normalizeEnvironment(undefined), null);
});

Deno.test("the notification signing time orders writes, the transaction time is the fallback", () => {
  assertEquals(
    signedDateOf({ signedDate: now }, { signedDate: past }),
    new Date(now).toISOString(),
  );
  assertEquals(signedDateOf({}, { signedDate: past }), new Date(past).toISOString());
  assertEquals(signedDateOf({}, {}), null);
});

Deno.test("a bundle id is accepted only when it is missing or ours", () => {
  assertEquals(matchesBundle("app.corbie", "app.corbie"), true);
  assertEquals(matchesBundle(undefined, "app.corbie"), true);
  assertEquals(matchesBundle("com.attacker.app", "app.corbie"), false);
});

Deno.test("payer hash is stable and does not contain the transaction id", async () => {
  const hash = await payerHash("2000000123456789");
  assertEquals(hash, await payerHash("2000000123456789"));
  assertEquals(hash?.length, 64);
  assertEquals(hash?.includes("2000000123456789"), false);
  assertEquals(await payerHash(undefined), null);
});
