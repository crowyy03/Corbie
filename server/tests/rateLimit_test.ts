import { assertEquals, assertNotEquals } from "@std/assert";
import { clientKey } from "../supabase/functions/_shared/rateLimit.ts";

function request(headers: Record<string, string>): Request {
  return new Request("https://corbie.test/parse", { method: "POST", headers });
}

Deno.test("a caller cannot escape its bucket by prepending a forwarded entry", async () => {
  const spoofed = await clientKey(request({ "x-forwarded-for": "1.2.3.4, 203.0.113.7" }));
  assertEquals(spoofed, "203.0.113.7");
  assertEquals(spoofed, await clientKey(request({ "x-forwarded-for": "203.0.113.7" })));
  assertEquals(spoofed, await clientKey(request({ "x-forwarded-for": "9.9.9.9, 203.0.113.7" })));
});

Deno.test("the address the gateway sets itself wins over the forwarded chain", async () => {
  const key = await clientKey(request({
    "x-forwarded-for": "1.2.3.4, 5.6.7.8",
    "cf-connecting-ip": "203.0.113.7",
  }));
  assertEquals(key, "203.0.113.7");
});

Deno.test("without any address the bucket follows the anonymous id", async () => {
  const key = await clientKey(request({ "x-anon-id": "3f1f0a2c-3d3e-4f52-9a0f-8f1f0a2c3d3e" }));
  assertEquals(key.startsWith("anon:"), true);
  assertEquals(
    key,
    await clientKey(request({ "x-anon-id": "3f1f0a2c-3d3e-4f52-9a0f-8f1f0a2c3d3e" })),
  );
  assertNotEquals(key, await clientKey(request({ "x-anon-id": "other" })));
  assertEquals(await clientKey(request({})), "unknown");
});
