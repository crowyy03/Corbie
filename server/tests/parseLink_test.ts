import { assertEquals } from "@std/assert";
import { parseLink } from "../supabase/functions/_shared/parse/index.ts";

function htmlFetch(html: string, init: ResponseInit = {}): typeof fetch {
  return () =>
    Promise.resolve(
      new Response(html, { headers: { "content-type": "text/html; charset=utf-8" }, ...init }),
    );
}

async function fixture(name: string): Promise<string> {
  return await Deno.readTextFile(new URL(`./fixtures/${name}`, import.meta.url));
}

Deno.test("a product page becomes the response shape the client expects", async () => {
  const result = await parseLink(
    "https://www.amazon.com/Hario-Dripper/dp/B000P4D5HG?tag=aff-20",
    htmlFetch(await fixture("amazon.html")),
  );
  assertEquals(result, {
    canonicalURL: "https://www.amazon.com/dp/B000P4D5HG",
    source: "amazon",
    title: "Hario V60 Ceramic Coffee Dripper, Size 02, White",
    price: 24.9,
    currency: "USD",
    imageURL: "https://m.media-amazon.com/images/I/71dripper._AC_SL1500_.jpg",
    author: "Visit the Hario Store",
  });
});

Deno.test("relative image urls are resolved against the page", async () => {
  const result = await parseLink(
    "https://kleinerladen.de/vasen/nord",
    htmlFetch(await fixture("generic-og.html")),
  );
  assertEquals(result.source, "generic");
  assertEquals(result.imageURL, "https://kleinerladen.de/media/vase-nord.jpg");
  assertEquals(result.price, 1234.56);
  assertEquals(result.currency, "EUR");
});

Deno.test("an upstream error degrades to canonical url and source", async () => {
  const failing: typeof fetch = () => Promise.reject(new Error("timeout"));
  const result = await parseLink("https://www.target.com/p/mug/-/A-123?ref=email", failing);
  assertEquals(result, {
    canonicalURL: "https://www.target.com/p/mug/-/A-123",
    source: "target",
    title: null,
    price: null,
    currency: null,
    imageURL: null,
    author: null,
  });
});

Deno.test("a non-html response degrades instead of returning bytes", async () => {
  const pdf: typeof fetch = () =>
    Promise.resolve(new Response("%PDF-1.4", { headers: { "content-type": "application/pdf" } }));
  const result = await parseLink("https://example.com/catalog.pdf", pdf);
  assertEquals(result.title, null);
  assertEquals(result.imageURL, null);
});

Deno.test("an endless body is cut off at the cap instead of being buffered whole", async () => {
  const chunk = new TextEncoder().encode("x".repeat(256 * 1024));
  let produced = 0;
  const endless: typeof fetch = () =>
    Promise.resolve(
      new Response(
        new ReadableStream<Uint8Array>({
          start(controller) {
            controller.enqueue(
              new TextEncoder().encode("<html><head><title>Big page</title></head><body>"),
            );
          },
          pull(controller) {
            produced += 1;
            if (produced > 64) {
              controller.close();
              return;
            }
            controller.enqueue(chunk);
          },
        }),
        { headers: { "content-type": "text/html" } },
      ),
    );

  const result = await parseLink("https://example.com/big", endless);
  assertEquals(result.title, "Big page");
  assertEquals(produced <= 13, true, `produced ${produced} chunks`);
});

Deno.test("a 404 degrades instead of parsing the error page", async () => {
  const missing = htmlFetch("<html><head><title>Not found</title></head></html>", { status: 404 });
  const result = await parseLink("https://example.com/gone", missing);
  assertEquals(result.title, null);
});

Deno.test("the response never carries html", async () => {
  const result = await parseLink(
    "https://www.etsy.com/listing/1/apron",
    htmlFetch(await fixture("etsy.html")),
  );
  const serialized = JSON.stringify(result);
  assertEquals(serialized.includes("<"), false);
  assertEquals(Object.keys(result).sort(), [
    "author",
    "canonicalURL",
    "currency",
    "imageURL",
    "price",
    "source",
    "title",
  ]);
});
