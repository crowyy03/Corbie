import { assertEquals } from "@std/assert";
import type { ParseResult } from "../supabase/functions/_shared/parse/index.ts";
import { parseLink } from "../supabase/functions/_shared/parse/index.ts";

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
