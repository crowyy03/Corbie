import { assertEquals, assertThrows } from "@std/assert";
import {
  hostOf,
  isAmazonShortLink,
  normalizeUrl,
  resolveShortLink,
} from "../supabase/functions/_shared/parse/normalizeUrl.ts";

Deno.test("strips utm, fbclid and ref", () => {
  assertEquals(
    normalizeUrl("https://shop.example.com/p/42?utm_source=ig&utm_medium=story&color=sage"),
    "https://shop.example.com/p/42?color=sage",
  );
  assertEquals(
    normalizeUrl("https://shop.example.com/p/42?fbclid=ABC&ref=newsletter"),
    "https://shop.example.com/p/42",
  );
});

Deno.test("keeps parameters the page actually needs", () => {
  assertEquals(
    normalizeUrl("https://shop.example.com/p?size=M&variant=7"),
    "https://shop.example.com/p?size=M&variant=7",
  );
});

Deno.test("rewrites amazon product urls to the bare asin", () => {
  assertEquals(
    normalizeUrl(
      "https://www.amazon.com/Hario-Ceramic-Coffee-Dripper/dp/B000P4D5HG/ref=sr_1_3?tag=aff-20&qid=17",
    ),
    "https://www.amazon.com/dp/B000P4D5HG",
  );
  assertEquals(
    normalizeUrl("https://www.amazon.co.uk/gp/product/B000P4D5HG?psc=1&th=1"),
    "https://www.amazon.co.uk/dp/B000P4D5HG",
  );
});

Deno.test("drops the amazon affiliate tag even without an asin", () => {
  assertEquals(
    normalizeUrl("https://www.amazon.com/s?k=coffee&tag=aff-20&crid=XYZ"),
    "https://www.amazon.com/s?k=coffee",
  );
});

Deno.test("normalizes scheme, case, hash and trailing slash", () => {
  assertEquals(normalizeUrl("http://WWW.Example.COM/p/1/#reviews"), "https://www.example.com/p/1");
  assertEquals(hostOf(new URL("https://www.etsy.com/listing/1")), "etsy.com");
});

Deno.test("rejects unsupported urls", () => {
  assertThrows(() => normalizeUrl("corbie://join/K7M2QX"));
  assertThrows(() => normalizeUrl("not a url"));
});

Deno.test("recognizes amazon short links", () => {
  assertEquals(isAmazonShortLink("https://a.co/d/1a2b3c"), true);
  assertEquals(isAmazonShortLink("https://amzn.to/3xyz"), true);
  assertEquals(isAmazonShortLink("https://www.amazon.com/dp/B000P4D5HG"), false);
});

Deno.test("follows amazon short link redirects", async () => {
  const seen: string[] = [];
  const fetchImpl: typeof fetch = (input) => {
    const url = input instanceof Request ? input.url : String(input);
    seen.push(url);
    if (url.startsWith("https://a.co/")) {
      return Promise.resolve(
        new Response(null, {
          status: 301,
          headers: { location: "https://www.amazon.com/dp/B000P4D5HG?tag=aff-20" },
        }),
      );
    }
    return Promise.resolve(new Response(null, { status: 200 }));
  };

  const resolved = await resolveShortLink("https://a.co/d/1a2b3c", fetchImpl);
  assertEquals(normalizeUrl(resolved), "https://www.amazon.com/dp/B000P4D5HG");
  assertEquals(seen.length, 2);
});

Deno.test("leaves non short links untouched", async () => {
  let called = 0;
  const fetchImpl: typeof fetch = () => {
    called += 1;
    return Promise.resolve(new Response(null, { status: 200 }));
  };
  const url = "https://www.etsy.com/listing/1";
  assertEquals(await resolveShortLink(url, fetchImpl), url);
  assertEquals(called, 0);
});
