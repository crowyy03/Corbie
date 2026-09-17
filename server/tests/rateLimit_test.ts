import { assert, assertEquals, assertNotEquals, assertRejects } from "@std/assert";
import { clientKey } from "../supabase/functions/_shared/rateLimit.ts";
import { ApiError } from "../supabase/functions/_shared/respond.ts";

function request(headers: Record<string, string>): Request {
  return new Request("https://corbie.test/parse", { method: "POST", headers });
}

async function withSalt<T>(salt: string, run: () => Promise<T>): Promise<T> {
  Deno.env.set("RATE_LIMIT_SALT", salt);
  try {
    return await run();
  } finally {
    Deno.env.delete("RATE_LIMIT_SALT");
  }
}

Deno.test("a caller cannot escape its bucket by prepending a forwarded entry", async () => {
  await withSalt("test-salt", async () => {
    const spoofed = await clientKey(request({ "x-forwarded-for": "1.2.3.4, 203.0.113.7" }));
    assertEquals(spoofed, await clientKey(request({ "x-forwarded-for": "203.0.113.7" })));
    assertEquals(spoofed, await clientKey(request({ "x-forwarded-for": "9.9.9.9, 203.0.113.7" })));
    assertNotEquals(spoofed, await clientKey(request({ "x-forwarded-for": "1.2.3.4" })));
  });
});

Deno.test("the address the gateway sets itself wins over the forwarded chain", async () => {
  await withSalt("test-salt", async () => {
    const key = await clientKey(request({
      "x-forwarded-for": "1.2.3.4, 5.6.7.8",
      "cf-connecting-ip": "203.0.113.7",
    }));
    assertEquals(key, await clientKey(request({ "x-real-ip": "203.0.113.7" })));
    assertNotEquals(key, await clientKey(request({ "x-forwarded-for": "5.6.7.8" })));
  });
});

Deno.test("the key never carries the address, only a salted digest of it", async () => {
  const address = "203.0.113.7";
  const first = await withSalt(
    "salt-one",
    () => clientKey(request({ "cf-connecting-ip": address })),
  );
  const second = await withSalt(
    "salt-two",
    () => clientKey(request({ "cf-connecting-ip": address })),
  );
  for (const key of [first, second]) {
    assert(key.startsWith("ip:"), key);
    assertEquals(key.length, "ip:".length + 32);
    assertEquals(key.includes(address), false);
    assertEquals(key.includes("203"), false);
  }
  assertNotEquals(first, second);
});

Deno.test("without any address the bucket follows a salted digest of the anonymous id", async () => {
  const anon = "3f1f0a2c-3d3e-4f52-9a0f-8f1f0a2c3d3e";
  await withSalt("test-salt", async () => {
    const key = await clientKey(request({ "x-anon-id": anon }));
    assert(key.startsWith("anon:"), key);
    assertEquals(key.includes(anon), false);
    assertEquals(key, await clientKey(request({ "x-anon-id": anon })));
    assertNotEquals(key, await clientKey(request({ "x-anon-id": "other" })));
    assertEquals(await clientKey(request({})), "unknown");
  });
  const resalted = await withSalt("other-salt", () => clientKey(request({ "x-anon-id": anon })));
  const original = await withSalt("test-salt", () => clientKey(request({ "x-anon-id": anon })));
  assertNotEquals(resalted, original);
});

Deno.test("without the salt the key is refused instead of falling back to the raw value", async () => {
  Deno.env.delete("RATE_LIMIT_SALT");
  const refused: Record<string, string>[] = [{ "cf-connecting-ip": "203.0.113.7" }, {
    "x-anon-id": "abc",
  }];
  for (const headers of refused) {
    const error = await assertRejects(() => clientKey(request(headers)), ApiError);
    assertEquals(error.code, "internal");
  }
  assertEquals(await clientKey(request({})), "unknown");
});
