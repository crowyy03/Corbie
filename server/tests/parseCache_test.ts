import { assertEquals } from "@std/assert";
import { safeFetchWith } from "../supabase/functions/_shared/parse/guard.ts";
import type { ParseResult } from "../supabase/functions/_shared/parse/index.ts";
import {
  extractFields,
  landedOffProduct,
  parseLink,
} from "../supabase/functions/_shared/parse/index.ts";

const realServe = Object.getOwnPropertyDescriptor(Deno, "serve")!;
Object.defineProperty(Deno, "serve", { configurable: true, value: () => {} });
const { isWorthCaching } = await import("../supabase/functions/parse/index.ts");
Object.defineProperty(Deno, "serve", realServe);

function result(fields: Partial<ParseResult>): ParseResult {
  return {
    canonicalURL: "https://shop.example.com/p/1",
    source: "generic",
    title: null,
    price: null,
    currency: null,
    imageURL: null,
    author: null,
    ...fields,
  };
}

const complete: Partial<ParseResult> = {
  title: "Vase",
  price: 129,
  currency: "EUR",
  imageURL: "https://shop.example.com/vase.jpg",
};

Deno.test("only a shop result with title, photo, price and currency is kept for a day", () => {
  assertEquals(isWorthCaching(result(complete)), true);
  assertEquals(isWorthCaching(result({ ...complete, author: "Some Brand" })), true);
});

Deno.test("a partial shop result is never cached", () => {
  assertEquals(isWorthCaching(result({})), false);
  assertEquals(isWorthCaching(result({ author: "Some Brand" })), false);
  assertEquals(isWorthCaching(result({ title: "Vase" })), false);
  assertEquals(isWorthCaching(result({ imageURL: "https://shop.example.com/vase.jpg" })), false);
  assertEquals(isWorthCaching(result({ ...complete, price: null, currency: null })), false);
  assertEquals(isWorthCaching(result({ ...complete, currency: null })), false);
  assertEquals(isWorthCaching(result({ ...complete, imageURL: null })), false);
  assertEquals(isWorthCaching(result({ ...complete, title: null })), false);
});

Deno.test("an instagram or tiktok result is kept when oembed gave its image", () => {
  const image = "https://p16.tiktokcdn.com/cover.jpeg";
  assertEquals(isWorthCaching(result({ source: "tiktok", imageURL: image })), true);
  assertEquals(isWorthCaching(result({ source: "instagram", imageURL: image })), true);
  assertEquals(isWorthCaching(result({ source: "tiktok" })), false);
});

Deno.test("a site that refuses the datacenter stays uncached, so the next try goes out again", async () => {
  const refusing: typeof fetch = () =>
    Promise.resolve(
      new Response("<html><head><title>Access Denied</title></head></html>", {
        status: 403,
        headers: { "content-type": "text/html" },
      }),
    );
  const { result: refused } = await parseLink("https://www.example.com/p/bag", refusing);
  assertEquals(refused.title, null);
  assertEquals(refused.imageURL, null);
  assertEquals(isWorthCaching(refused), false);
});

const ikeaProduct = "https://www.ikea.com/us/en/p/kallax-shelf-unit-white-80275887/";
const ikeaCategory = "https://www.ikea.com/us/en/cat/products-products/";

async function fixture(name: string): Promise<string> {
  return await Deno.readTextFile(new URL(`./fixtures/${name}`, import.meta.url));
}

function answeredAs(url: string, response: Response): Response {
  Object.defineProperty(response, "url", { value: url });
  return response;
}

function shop(pages: Record<string, { redirect: string } | { html: string }>): typeof fetch {
  const served: typeof fetch = (input) => {
    const url = input instanceof Request ? input.url : input.toString();
    const page = pages[url];
    if (!page) return Promise.resolve(answeredAs(url, new Response("gone", { status: 404 })));
    if ("redirect" in page) {
      return Promise.resolve(
        answeredAs(url, new Response(null, { status: 301, headers: { location: page.redirect } })),
      );
    }
    return Promise.resolve(
      answeredAs(url, new Response(page.html, { headers: { "content-type": "text/html" } })),
    );
  };
  return safeFetchWith(served, () => Promise.resolve(["93.184.216.34"]));
}

Deno.test("the ikea category page on its own is not read as a product either", async () => {
  const reading = extractFields(await fixture("ikea-category.html"), new URL(ikeaCategory));
  assertEquals(reading.fields.title, "Products");
  assertEquals(reading.isProductPage, false);
});

Deno.test("an ikea product link that lands on a category comes back bare and uncached", async () => {
  const fetchImpl = shop({
    [ikeaProduct.replace(/\/$/, "")]: { redirect: ikeaProduct },
    [ikeaProduct]: { redirect: "/us/en/cat/products-products/" },
    [ikeaCategory]: { html: await fixture("ikea-category.html") },
  });
  const { result, trace } = await parseLink(ikeaProduct, fetchImpl);
  assertEquals(trace.upstream, "redirect");
  assertEquals(result, {
    canonicalURL: ikeaProduct.replace(/\/$/, ""),
    source: "ikea",
    title: null,
    price: null,
    currency: null,
    imageURL: null,
    author: null,
  });
  assertEquals(isWorthCaching(result), false);
});

Deno.test("an ikea product link that stays on the product page is read as before", async () => {
  const html = await fixture("ikea.html");
  const fetchImpl = shop({
    [ikeaProduct.replace(/\/$/, "")]: { redirect: ikeaProduct },
    [ikeaProduct]: { html },
  });
  const { result } = await parseLink(ikeaProduct, fetchImpl);
  assertEquals(result.title, "BILLY Bookcase, white");
  assertEquals(result.price, 69.99);
  assertEquals(isWorthCaching(result), true);
});

Deno.test("an ikea product that moved to another product page is still read", async () => {
  const moved = "https://www.ikea.com/us/en/p/kallax-shelf-unit-white-20275814/";
  const fetchImpl = shop({
    [ikeaProduct.replace(/\/$/, "")]: { redirect: moved },
    [ikeaProduct]: { redirect: moved },
    [moved]: { html: await fixture("ikea.html") },
  });
  const { result } = await parseLink(ikeaProduct, fetchImpl);
  assertEquals(result.title, "BILLY Bookcase, white");
});

Deno.test("only a shop that knows its product paths judges where a link landed", () => {
  assertEquals(landedOffProduct(new URL(ikeaProduct), new URL(ikeaCategory)), true);
  assertEquals(landedOffProduct(new URL(ikeaProduct), new URL(ikeaProduct)), false);
  assertEquals(landedOffProduct(new URL(ikeaCategory), new URL(ikeaCategory)), false);
  assertEquals(
    landedOffProduct(
      new URL("https://kleinerladen.de/vasen/nord"),
      new URL("https://kleinerladen.de/vasen/"),
    ),
    false,
  );
});

Deno.test("a country selector answered instead of the product is bare and not cached", async () => {
  const url = "https://www.bestbuy.com/site/apple-airpods-pro/6447382.p?skuId=6447382";
  const fetchImpl = shop({ [url]: { html: await fixture("bestbuy-country-selector.html") } });
  const { result } = await parseLink(url, fetchImpl);
  assertEquals(result.title, null);
  assertEquals(isWorthCaching(result), false);
});

Deno.test("an amazon page with no price for this country is returned but not cached", async () => {
  const url = "https://www.amazon.com/dp/B0CHWRXH8B";
  const fetchImpl = shop({
    [url]: { html: await fixture("amazon-mobile-deliver-to-finland.html") },
  });
  const { result } = await parseLink(url, fetchImpl);
  assertEquals(result.price, null);
  assertEquals(result.title !== null && result.imageURL !== null, true);
  assertEquals(isWorthCaching(result), false);
});
