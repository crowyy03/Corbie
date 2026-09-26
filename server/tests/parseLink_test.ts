import { assertEquals } from "@std/assert";
import { safeFetchWith } from "../supabase/functions/_shared/parse/guard.ts";
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
  const { result } = await parseLink(
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
  const { result } = await parseLink(
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
  const { result } = await parseLink("https://www.target.com/p/mug/-/A-123?ref=email", failing);
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
  const { result } = await parseLink("https://example.com/catalog.pdf", pdf);
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
              new TextEncoder().encode(
                '<html><head><title>Big page</title><meta property="og:image" content="/big.jpg"></head><body>',
              ),
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

  const { result } = await parseLink("https://example.com/big", endless);
  assertEquals(result.title, "Big page");
  assertEquals(produced <= 13, true, `produced ${produced} chunks`);
});

Deno.test("a page with nothing but a title comes back bare", async () => {
  const { result, trace } = await parseLink(
    "https://example.com/big",
    htmlFetch("<html><head><title>Big page</title></head><body>text</body></html>"),
  );
  assertEquals(result.title, null);
  assertEquals(trace.page, "not-product");
});

Deno.test("a title that only the title element gives is traced to it, not to open graph", async () => {
  const { result, trace } = await parseLink(
    "https://example.com/vase",
    htmlFetch(
      '<html><head><title>Vase</title><meta property="og:image" content="/vase.jpg"></head></html>',
    ),
  );
  assertEquals(result.title, "Vase");
  assertEquals(trace.titleFrom, "title-tag");
});

Deno.test("a 404 degrades instead of parsing the error page", async () => {
  const missing = htmlFetch("<html><head><title>Not found</title></head></html>", { status: 404 });
  const { result } = await parseLink("https://example.com/gone", missing);
  assertEquals(result.title, null);
});

Deno.test("the response never carries html", async () => {
  const { result } = await parseLink(
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

Deno.test("a country selector page is not a product: bare, with the verdict in the trace", async () => {
  const { result, trace } = await parseLink(
    "https://www.bestbuy.com/site/apple-airpods-pro-2nd-generation-with-magsafe-case-usbc-white/6447382.p?skuId=6447382",
    htmlFetch(await fixture("bestbuy-country-selector.html")),
  );
  assertEquals(result, {
    canonicalURL:
      "https://www.bestbuy.com/site/apple-airpods-pro-2nd-generation-with-magsafe-case-usbc-white/6447382.p?skuId=6447382",
    source: "generic",
    title: null,
    price: null,
    currency: null,
    imageURL: null,
    author: null,
  });
  assertEquals(trace, { upstream: 200, page: "not-product", titleFrom: "none", priceFrom: "none" });
});

Deno.test("the trace names which reader gave the title and the price", async () => {
  const { trace } = await parseLink(
    "https://www.walmart.com/ip/Apple-AirPods-4/11381374703",
    htmlFetch(await fixture("walmart.html")),
  );
  assertEquals(trace, { upstream: 200, page: "product", titleFrom: "og", priceFrom: "microdata" });
});

Deno.test("the trace names each way the fetch can fail", async () => {
  const url = "https://shop.example.com/p/vase";
  const upstreamOf = async (fetchImpl: typeof fetch) =>
    (await parseLink(url, fetchImpl)).trace.upstream;

  assertEquals(
    await upstreamOf(() => Promise.reject(new DOMException("signal timed out", "TimeoutError"))),
    "timeout",
  );
  assertEquals(
    await upstreamOf(
      safeFetchWith(
        () => Promise.reject(new Error("never fetched")),
        () => Promise.resolve(["10.0.0.7"]),
      ),
    ),
    "guard",
  );
  assertEquals(
    await upstreamOf(
      safeFetchWith(() => Promise.reject(new Error("never fetched")), () => Promise.resolve([])),
    ),
    "unresolved",
  );
  assertEquals(
    await upstreamOf(
      safeFetchWith(
        (input) =>
          Promise.resolve(
            new Response(null, { status: 302, headers: { location: `${input}/next` } }),
          ),
        () => Promise.resolve(["93.184.216.34"]),
      ),
    ),
    "too-many-redirects",
  );
  assertEquals(
    await upstreamOf(() => Promise.reject(new TypeError("http2 error: stream error received"))),
    "error",
  );
  assertEquals(await upstreamOf(htmlFetch("<html></html>", { status: 403 })), 403);
  assertEquals(
    await upstreamOf(() =>
      Promise.resolve(new Response("%PDF-1.4", { headers: { "content-type": "application/pdf" } }))
    ),
    "non-html",
  );
});
