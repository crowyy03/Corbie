import { assertEquals, assertRejects, assertThrows } from "@std/assert";
import {
  ApiError,
  empty,
  type ErrorCode,
  errorResponse,
  failure,
  isUuid,
  json,
  pathSegments,
  readJson,
  requireMethod,
  requireUuid,
} from "../supabase/functions/_shared/respond.ts";

Deno.test("every error code maps to the status the contract promises", async () => {
  const expected: Record<ErrorCode, number> = {
    unauthorized: 401,
    invalid_request: 400,
    not_found: 404,
    expired: 410,
    redeemed: 410,
    rate_limited: 429,
    upstream_failed: 502,
    internal: 500,
  };
  for (const [code, status] of Object.entries(expected)) {
    const response = failure(code as ErrorCode, "human text");
    assertEquals(response.status, status, code);
    assertEquals(await response.json(), { error: code, message: "human text" });
  }
});

Deno.test("responses carry json content type and no cors headers", async () => {
  const response = json({ ok: true }, 201);
  assertEquals(response.status, 201);
  assertEquals(response.headers.get("content-type"), "application/json; charset=utf-8");
  assertEquals(response.headers.get("cache-control"), "no-store");
  assertEquals(response.headers.get("access-control-allow-origin"), null);
  assertEquals(await response.json(), { ok: true });

  const bodyless = empty(204);
  assertEquals(bodyless.status, 204);
  assertEquals(bodyless.body, null);
});

Deno.test("an unexpected failure becomes an internal envelope", async () => {
  const response = errorResponse(new TypeError("boom"));
  assertEquals(response.status, 500);
  assertEquals((await response.json()).error, "internal");
});

Deno.test("the wrong method is refused with 405", () => {
  const request = new Request("https://example.com/invite", { method: "GET" });
  const error = assertThrows(() => requireMethod(request, "POST"), ApiError) as ApiError;
  assertEquals(error.status, 405);
  assertEquals(error.code, "invalid_request");
});

Deno.test("path segments are read after the function name", () => {
  const build = (path: string) => new Request(`https://ref.supabase.co${path}`);
  assertEquals(pathSegments(build("/functions/v1/entitlement/abc"), "entitlement"), ["abc"]);
  assertEquals(pathSegments(build("/entitlement/abc"), "entitlement"), ["abc"]);
  assertEquals(pathSegments(build("/invite-redeem/K7M2QX"), "invite-redeem"), ["K7M2QX"]);
  assertEquals(pathSegments(build("/invite-redeem"), "invite-redeem"), []);
  assertEquals(pathSegments(build("/functions/v1/invite-redeem/K7%20M"), "invite-redeem"), [
    "K7 M",
  ]);
});

Deno.test("uuid checks accept the space id shape and reject the rest", () => {
  assertEquals(isUuid("11111111-1111-4111-8111-111111111111"), true);
  assertEquals(isUuid("11111111111141118111111111111111"), false);
  assertEquals(isUuid(""), false);
  assertEquals(isUuid(42), false);
  assertEquals(
    requireUuid("11111111-1111-4111-8111-11111111ABCD", "spaceId"),
    "11111111-1111-4111-8111-11111111abcd",
  );
  assertThrows(() => requireUuid("nope", "spaceId"), ApiError, "spaceId must be a UUID");
});

Deno.test("bodies must be declared and be valid json", async () => {
  const noType = new Request("https://example.com", { method: "POST", body: "{}" });
  await assertRejects(() => readJson(noType), ApiError, "Content-Type");

  const broken = new Request("https://example.com", {
    method: "POST",
    body: "{",
    headers: { "content-type": "application/json" },
  });
  await assertRejects(() => readJson(broken), ApiError, "valid JSON");

  const good = new Request("https://example.com", {
    method: "POST",
    body: JSON.stringify({ url: "https://example.com" }),
    headers: { "content-type": "application/json" },
  });
  assertEquals(await readJson(good), { url: "https://example.com" });
});
