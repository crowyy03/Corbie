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

Deno.test("a result with nothing in it is never cached", () => {
  assertEquals(isWorthCaching(result({})), false);
  assertEquals(isWorthCaching(result({ author: "Some Brand" })), false);
  assertEquals(isWorthCaching(result({ price: 129, currency: "EUR" })), false);
});

Deno.test("a title or an image is worth keeping for a day", () => {
  assertEquals(isWorthCaching(result({ title: "Vase" })), true);
  assertEquals(isWorthCaching(result({ imageURL: "https://shop.example.com/vase.jpg" })), true);
});

Deno.test("a site that refuses the datacenter stays uncached, so the next try goes out again", async () => {
  const refusing: typeof fetch = () =>
    Promise.resolve(
      new Response("<html><head><title>Access Denied</title></head></html>", {
        status: 403,
        headers: { "content-type": "text/html" },
      }),
    );
  const refused = await parseLink("https://www.example.com/p/bag", refusing);
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

Deno.test("the ikea category page on its own reads as a product called Products", async () => {
  const fields = extractFields(await fixture("ikea-category.html"), "ikea.com");
  assertEquals(fields.title, "Products");
});

Deno.test("an ikea product link that lands on a category comes back bare and uncached", async () => {
  const fetchImpl = shop({
    [ikeaProduct.replace(/\/$/, "")]: { redirect: ikeaProduct },
    [ikeaProduct]: { redirect: "/us/en/cat/products-products/" },
    [ikeaCategory]: { html: await fixture("ikea-category.html") },
  });
  const result = await parseLink(ikeaProduct, fetchImpl);
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
  const result = await parseLink(ikeaProduct, fetchImpl);
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
  const result = await parseLink(ikeaProduct, fetchImpl);
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
