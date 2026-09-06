import { assert, assertEquals, assertThrows } from "@std/assert";
import {
  allowedEventNames,
  droppedPropKeys,
  maxEventsPerBatch,
  requireAnonId,
  sanitizeBatch,
  sanitizeProps,
} from "../supabase/functions/_shared/events.ts";
import { ApiError } from "../supabase/functions/_shared/respond.ts";

const anonId = "11111111-1111-4111-8111-111111111111";
const now = new Date("2026-09-05T10:00:00.000Z");

Deno.test("anon id must be a uuid", () => {
  assertEquals(requireAnonId(anonId.toUpperCase()), anonId);
  assertThrows(() => requireAnonId(null), ApiError);
  assertThrows(() => requireAnonId("not-a-uuid"), ApiError);
});

Deno.test("the allowlist matches the architecture event list", () => {
  for (const name of ["app_open", "wish_created", "paywall_shown", "purchase", "readonly_hit"]) {
    assert(allowedEventNames.has(name), name);
  }
  assertEquals(allowedEventNames.size, 42);
});

Deno.test("events outside the allowlist are dropped, not rejected", () => {
  const rows = sanitizeBatch(anonId, {
    events: [
      { name: "task_created" },
      { name: "screenshot_taken" },
      { name: "" },
      { name: 42 },
      "nonsense",
    ],
  }, now);
  assertEquals(rows.length, 1);
  assertEquals(rows[0].name, "task_created");
});

Deno.test("props keys that can carry personal data are dropped", () => {
  const props = sanitizeProps({
    assignee: "partner",
    email: "a@b.com",
    Name: "Sasha",
    TITLE: "Buy milk for mum",
    body: "note",
    text: "note",
    url: "https://example.com/private",
    phone: "+1000",
    count: 3,
    done: true,
    missing: null,
  });
  assertEquals(props, { assignee: "partner", count: 3, done: true, missing: null });
  for (const key of droppedPropKeys) assertEquals(key in props, false, key);
});

Deno.test("props are capped at ten keys and scalar values only", () => {
  const wide: Record<string, unknown> = {};
  for (let i = 0; i < 20; i++) wide[`k${i}`] = i;
  assertEquals(Object.keys(sanitizeProps(wide)).length, 10);

  const props = sanitizeProps({
    nested: { a: 1 },
    list: [1, 2],
    fn: "ok",
    bad: Number.NaN,
  });
  assertEquals(props, { fn: "ok" });

  const long = sanitizeProps({ note: "x".repeat(500) });
  assertEquals((long.note as string).length, 200);
});

Deno.test("timestamps outside the retention window snap to now", () => {
  const rows = sanitizeBatch(anonId, {
    events: [
      { name: "app_open", ts: "2026-09-05T09:00:00.000Z" },
      { name: "app_open", ts: "2019-01-01T00:00:00.000Z" },
      { name: "app_open", ts: "2099-01-01T00:00:00.000Z" },
      { name: "app_open", ts: "yesterday" },
      { name: "app_open" },
    ],
  }, now);
  assertEquals(rows.map((row) => row.ts), [
    "2026-09-05T09:00:00.000Z",
    now.toISOString(),
    now.toISOString(),
    now.toISOString(),
    now.toISOString(),
  ]);
});

Deno.test("app version and locale are trimmed and capped", () => {
  const rows = sanitizeBatch(anonId, {
    events: [{ name: "app_open", appVersion: "  1.0 (12)  ", locale: "en_US" }, {
      name: "app_open",
      appVersion: 7,
      locale: "  ",
    }],
  }, now);
  assertEquals(rows[0].app_version, "1.0 (12)");
  assertEquals(rows[0].locale, "en_US");
  assertEquals(rows[1].app_version, null);
  assertEquals(rows[1].locale, null);
});

Deno.test("a batch over the limit is rejected", () => {
  const events = Array.from({ length: maxEventsPerBatch + 1 }, () => ({ name: "app_open" }));
  assertThrows(() => sanitizeBatch(anonId, { events }, now), ApiError);
  assertEquals(sanitizeBatch(anonId, { events: events.slice(1) }, now).length, maxEventsPerBatch);
});

Deno.test("a body without an events array is rejected", () => {
  assertThrows(() => sanitizeBatch(anonId, {}, now), ApiError);
  assertThrows(() => sanitizeBatch(anonId, { events: "app_open" }, now), ApiError);
  assertThrows(() => sanitizeBatch(anonId, null, now), ApiError);
});
