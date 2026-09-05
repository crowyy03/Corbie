import { assertEquals, assertRejects } from "@std/assert";
import {
  assertFetchable,
  isPrivateAddress,
  safeFetchWith,
} from "../supabase/functions/_shared/parse/guard.ts";

const publicResolver = () => Promise.resolve(["93.184.216.34"]);

Deno.test("addresses inside the network are recognised in both families", () => {
  for (
    const address of [
      "0.0.0.0",
      "10.1.2.3",
      "127.0.0.1",
      "169.254.169.254",
      "172.16.0.1",
      "192.168.1.1",
      "100.64.0.1",
      "198.18.0.1",
      "224.0.0.1",
      "::1",
      "::",
      "::ffff:10.0.0.5",
      "64:ff9b::7f00:1",
      "fd00::1",
      "fe80::1",
      "ff02::1",
    ]
  ) {
    assertEquals(isPrivateAddress(address), true, address);
  }
});

Deno.test("public addresses stay reachable", () => {
  assertEquals(isPrivateAddress("93.184.216.34"), false);
  assertEquals(isPrivateAddress("8.8.8.8"), false);
  assertEquals(isPrivateAddress("2606:2800:220:1:248:1893:25c8:1946"), false);
});

Deno.test("a host that resolves inside the network is refused", async () => {
  const internal = () => Promise.resolve(["93.184.216.34", "10.0.0.5"]);
  await assertRejects(
    () => assertFetchable(new URL("https://shop.example.com/item"), internal),
    TypeError,
    "private network",
  );
});

Deno.test("addresses, private names, odd ports and other schemes are refused", async () => {
  await assertRejects(
    () => assertFetchable(new URL("https://169.254.169.254/latest"), publicResolver),
    TypeError,
    "not an address",
  );
  await assertRejects(
    () => assertFetchable(new URL("https://[::1]/latest"), publicResolver),
    TypeError,
    "not an address",
  );
  await assertRejects(
    () => assertFetchable(new URL("https://metadata.internal/latest"), publicResolver),
    TypeError,
    "private network",
  );
  await assertRejects(
    () => assertFetchable(new URL("https://shop.example.com:8080/item"), publicResolver),
    TypeError,
    "port",
  );
  await assertRejects(
    () => assertFetchable(new URL("file:///etc/passwd"), publicResolver),
    TypeError,
    "http or https",
  );
});

Deno.test("a host with no records is refused", async () => {
  await assertRejects(
    () => assertFetchable(new URL("https://nothing.example/item"), () => Promise.resolve([])),
    TypeError,
    "does not resolve",
  );
});

Deno.test("a public host is fetchable", async () => {
  await assertFetchable(new URL("https://shop.example.com/item"), publicResolver);
});

Deno.test("a redirect into the network is refused before it is followed", async () => {
  const visited: string[] = [];
  const inner: typeof fetch = (input) => {
    visited.push(input.toString());
    return Promise.resolve(
      new Response(null, { status: 302, headers: { location: "http://10.0.0.5:8080/admin" } }),
    );
  };
  const fetcher = safeFetchWith(inner, publicResolver);
  await assertRejects(() => fetcher("https://shop.example.com/item"), TypeError);
  assertEquals(visited, ["https://shop.example.com/item"]);
});

Deno.test("redirects are followed only five hops deep", async () => {
  let hop = 0;
  const inner: typeof fetch = () => {
    hop += 1;
    return Promise.resolve(
      new Response(null, {
        status: 302,
        headers: { location: `https://shop.example.com/hop-${hop}` },
      }),
    );
  };
  const fetcher = safeFetchWith(inner, publicResolver);
  await assertRejects(() => fetcher("https://shop.example.com/item"), TypeError, "too many times");
  assertEquals(hop, 6);
});

Deno.test("a caller that wants the redirect itself gets it validated but not followed", async () => {
  const inner: typeof fetch = () =>
    Promise.resolve(
      new Response(null, { status: 301, headers: { location: "https://www.amazon.com/dp/B0" } }),
    );
  const fetcher = safeFetchWith(inner, publicResolver);
  const response = await fetcher("https://a.co/d/abc", { redirect: "manual" });
  assertEquals(response.status, 301);
  assertEquals(response.headers.get("location"), "https://www.amazon.com/dp/B0");
});
