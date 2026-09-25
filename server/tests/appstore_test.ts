import { assertEquals } from "@std/assert";
import {
  matchesBundle,
  normalizeEnvironment,
  signedDateOf,
  statusFromAppleCode,
  statusFromNotificationType,
} from "../supabase/functions/_shared/appstore.ts";

const now = Date.UTC(2026, 8, 5, 10, 0, 0);
const future = now + 30 * 24 * 60 * 60 * 1000;
const past = now - 24 * 60 * 60 * 1000;

Deno.test("renewal events with a future expiry are active", () => {
  for (const type of ["SUBSCRIBED", "DID_RENEW", "DID_CHANGE_RENEWAL_STATUS", "OFFER_REDEEMED"]) {
    assertEquals(
      statusFromNotificationType(type, undefined, { expiresDate: future }, {}, now),
      "active",
      type,
    );
  }
});

Deno.test("a renewal event whose expiry already passed is expired", () => {
  assertEquals(
    statusFromNotificationType("DID_RENEW", undefined, { expiresDate: past }, {}, now),
    "expired",
  );
});

Deno.test("failed renewal inside the grace window is in_grace_period", () => {
  assertEquals(
    statusFromNotificationType(
      "DID_FAIL_TO_RENEW",
      "GRACE_PERIOD",
      { expiresDate: past },
      { gracePeriodExpiresDate: future },
      now,
    ),
    "in_grace_period",
  );
  assertEquals(
    statusFromNotificationType("DID_FAIL_TO_RENEW", "GRACE_PERIOD", { expiresDate: past }, {}, now),
    "in_grace_period",
  );
});

Deno.test("failed renewal that Apple is still retrying is in_billing_retry", () => {
  assertEquals(
    statusFromNotificationType(
      "DID_FAIL_TO_RENEW",
      undefined,
      { expiresDate: past },
      { isInBillingRetryPeriod: true },
      now,
    ),
    "in_billing_retry",
  );
  assertEquals(
    statusFromNotificationType(
      "DID_FAIL_TO_RENEW",
      "GRACE_PERIOD",
      { expiresDate: past },
      { gracePeriodExpiresDate: past, isInBillingRetryPeriod: true },
      now,
    ),
    "in_billing_retry",
  );
});

Deno.test("failed renewal with no grace window and no retry is expired", () => {
  assertEquals(
    statusFromNotificationType("DID_FAIL_TO_RENEW", undefined, { expiresDate: past }, {}, now),
    "expired",
  );
  assertEquals(
    statusFromNotificationType(
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
  assertEquals(statusFromNotificationType("EXPIRED", "VOLUNTARY", {}, {}, now), "expired");
  assertEquals(
    statusFromNotificationType("GRACE_PERIOD_EXPIRED", undefined, {}, {}, now),
    "expired",
  );
});

Deno.test("refund and revoke are revoked", () => {
  assertEquals(
    statusFromNotificationType("REFUND", undefined, { expiresDate: future }, {}, now),
    "revoked",
  );
  assertEquals(
    statusFromNotificationType("REVOKE", undefined, { expiresDate: future }, {}, now),
    "revoked",
  );
  assertEquals(
    statusFromNotificationType(
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
    statusFromNotificationType("TEST", undefined, { expiresDate: future }, {}, now),
    "active",
  );
  assertEquals(
    statusFromNotificationType("TEST", undefined, { expiresDate: past }, {}, now),
    "expired",
  );
  assertEquals(statusFromNotificationType("TEST", undefined, {}, {}, now), "none");
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

Deno.test("apple's subscription status codes map one to one", () => {
  assertEquals(statusFromAppleCode(1), "active");
  assertEquals(statusFromAppleCode(2), "expired");
  assertEquals(statusFromAppleCode(3), "in_billing_retry");
  assertEquals(statusFromAppleCode(4), "in_grace_period");
  assertEquals(statusFromAppleCode(5), "revoked");
  assertEquals(statusFromAppleCode(6), null);
  assertEquals(statusFromAppleCode(undefined), null);
});

Deno.test("without a status code a renewal event inside the grace window stays in grace", () => {
  for (const type of ["DID_CHANGE_RENEWAL_STATUS", "DID_CHANGE_RENEWAL_PREF", "PRICE_INCREASE"]) {
    assertEquals(
      statusFromNotificationType(
        type,
        undefined,
        { expiresDate: past },
        { gracePeriodExpiresDate: future },
        now,
      ),
      "in_grace_period",
      type,
    );
  }
});
