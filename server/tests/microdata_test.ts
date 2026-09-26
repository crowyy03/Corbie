import { assertEquals } from "@std/assert";
import { parseHtml } from "../supabase/functions/_shared/html.ts";
import { extractFields } from "../supabase/functions/_shared/parse/index.ts";
import { extractMicrodata } from "../supabase/functions/_shared/parse/microdata.ts";

async function fixture(name: string): Promise<string> {
  return await Deno.readTextFile(new URL(`./fixtures/${name}`, import.meta.url));
}

Deno.test("walmart's price comes from its microdata spans and its title loses the site name", async () => {
  const reading = extractFields(
    await fixture("walmart.html"),
    new URL("https://www.walmart.com/ip/Apple-AirPods-4/11381374703"),
  );
  assertEquals(reading.fields.price, 99);
  assertEquals(reading.fields.currency, "USD");
  assertEquals(reading.priceFrom, "microdata");
  assertEquals(reading.fields.title, "Apple AirPods 4");
});

Deno.test("microdata prices that disagree give no price", () => {
  const doc = parseHtml(`<html><body>
    <div><span itemprop="price" content="49.00">$49.00</span></div>
    <ul><li><span itemprop="price" content="12.00">$12.00</span></li></ul>
  </body></html>`);
  assertEquals(extractMicrodata(doc).price, null);
});

Deno.test("a meta itemprop price with its currency still reads", () => {
  const doc = parseHtml(`<html><head>
    <meta itemprop="price" content="1299.00"><meta itemprop="priceCurrency" content="chf">
  </head></html>`);
  const fields = extractMicrodata(doc);
  assertEquals(fields.price, 1299);
  assertEquals(fields.currency, "CHF");
});

Deno.test("the currency comes from the price text when the page declares none", () => {
  const doc = parseHtml(`<html><body>
    <span itemprop="price" content="Now $99.00"><span>$99.00</span></span>
  </body></html>`);
  const fields = extractMicrodata(doc);
  assertEquals(fields.price, 99);
  assertEquals(fields.currency, "USD");
});

Deno.test("the page's product item gives the price, not a product nested in it", () => {
  const doc = parseHtml(`<html><body itemscope itemtype="https://schema.org/WebPage">
    <div itemscope itemtype="https://schema.org/Product">
      <h1 itemprop="name">Main Vase</h1>
      <div itemprop="offers" itemscope itemtype="https://schema.org/Offer">
        <meta itemprop="price" content="129.00"><meta itemprop="priceCurrency" content="EUR">
      </div>
      <div itemprop="isRelatedTo" itemscope itemtype="https://schema.org/Product">
        <span itemprop="name">Related Mug</span>
        <div itemprop="offers" itemscope itemtype="https://schema.org/Offer">
          <meta itemprop="price" content="9.00"><meta itemprop="priceCurrency" content="USD">
        </div>
      </div>
    </div>
  </body></html>`);
  const fields = extractMicrodata(doc);
  assertEquals(fields.price, 129);
  assertEquals(fields.currency, "EUR");
});

Deno.test("prices of listed products or of several product items are not the page's", () => {
  const list = parseHtml(`<html><body>
    <ul itemscope itemtype="https://schema.org/ItemList">
      <li itemprop="itemListElement" itemscope itemtype="https://schema.org/Product">
        <span itemprop="price" content="9.00">9,00 EUR</span>
      </li>
    </ul>
  </body></html>`);
  assertEquals(extractMicrodata(list).price, null);

  const several = parseHtml(`<html><body>
    <div itemscope itemtype="https://schema.org/Product"><span itemprop="price" content="9.00"></span></div>
    <div itemscope itemtype="https://schema.org/Product"><span itemprop="price" content="9.00"></span></div>
  </body></html>`);
  assertEquals(extractMicrodata(several).price, null);
});

Deno.test("a price outside the page's product item is not read when the page has one", () => {
  const doc = parseHtml(`<html><body>
    <div itemscope itemtype="https://schema.org/Product"><h1 itemprop="name">Oak Table</h1></div>
    <aside><span itemprop="price" content="9.00">9,00 EUR</span></aside>
  </body></html>`);
  assertEquals(extractMicrodata(doc).price, null);
});

Deno.test("an open graph price outranks microdata", () => {
  const reading = extractFields(
    `<html><head>
      <meta property="og:title" content="Oak Table">
      <meta property="product:price:amount" content="420.00">
      <meta property="product:price:currency" content="EUR">
    </head><body><span itemprop="price" content="9.00">9,00 EUR</span></body></html>`,
    new URL("https://moebel.example/oak-table"),
  );
  assertEquals(reading.fields.price, 420);
  assertEquals(reading.priceFrom, "og");
});
