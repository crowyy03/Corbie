import { assertEquals } from "@std/assert";
import { parseHtml } from "../supabase/functions/_shared/html.ts";
import { extractFields } from "../supabase/functions/_shared/parse/index.ts";
import { extractJsonLd } from "../supabase/functions/_shared/parse/jsonld.ts";

async function fixture(name: string): Promise<string> {
  return await Deno.readTextFile(new URL(`./fixtures/${name}`, import.meta.url));
}

function jsonLdPage(data: unknown): string {
  return `<html><head><script type="application/ld+json">${
    JSON.stringify(data)
  }</script></head></html>`;
}

const hmBlackImage =
  "https://image.hm.com/assets/hm/fc/77/fc772bd40549837a94becd97c4bf73b27d33fc94.jpg?imwidth=768";
const nikeWhiteGumImage =
  "https://static.nike.com/a/images/t_default/u_9ddf04c7-2a9a-4d76-add1-d15af8f0263d,c_scale,fl_relative,w_1.0,h_1.0,fl_layer_apply/20795411-a573-4c33-b79b-a97c40b5c19a/AIR+FORCE+1+%2707.png";

Deno.test("an h&m link takes the colour its article code names, not the first variant", async () => {
  const reading = extractFields(
    await fixture("hm-product-group.html"),
    new URL("https://www2.hm.com/en_us/productpage.0685816002.html"),
  );
  assertEquals(reading.fields.title, "Regular Fit T-shirt - Black");
  assertEquals(reading.fields.imageURL, hmBlackImage);
  assertEquals(reading.fields.price, 7.99);
  assertEquals(reading.fields.currency, "USD");
});

Deno.test("an h&m article that is not on the page gets the group's name and no variant's photo or price", async () => {
  const reading = extractFields(
    await fixture("hm-product-group.html"),
    new URL("https://www2.hm.com/en_us/productpage.0685816099.html"),
  );
  assertEquals(reading.fields.title, "Regular Fit T-shirt");
  assertEquals(reading.fields.imageURL, null);
  assertEquals(reading.fields.price, null);
  assertEquals(reading.fields.currency, null);
});

Deno.test("a nike style-colour link reads its sizes as one product without the size in the title", async () => {
  const reading = extractFields(
    await fixture("nike-style-color.html"),
    new URL("https://www.nike.com/t/air-force-1-07-mens-shoes-XVPIszaq/FJ4146-136"),
  );
  assertEquals(
    reading.fields.title,
    "Nike Air Force 1 '07 Men's Shoes - White/Gum Light Brown/Challenge Red",
  );
  assertEquals(reading.fields.imageURL, nikeWhiteGumImage);
  assertEquals(reading.fields.price, 115);
  assertEquals(reading.fields.currency, "USD");
});

Deno.test("a nike link redirected to a group page without its colour gets no variant's photo or price", async () => {
  const reading = extractFields(
    await fixture("nike-group.html"),
    new URL("https://www.nike.com/t/air-force-1-07-mens-shoes-XVPIszaq/FJ4146-122"),
  );
  assertEquals(reading.fields.title, "Air Force 1 Low Men's Shoes");
  assertEquals(reading.fields.imageURL, null);
  assertEquals(reading.fields.price, null);
  assertEquals(reading.isProductPage, true);
});

Deno.test("a group whose variants all cost the same keeps that price when the link names none", () => {
  const doc = parseHtml(jsonLdPage({
    "@context": "https://schema.org",
    "@type": "ProductGroup",
    name: "Linen Napkin",
    image: "https://shop.example.com/napkin.jpg",
    hasVariant: [
      {
        "@type": "Product",
        sku: "NAP-SAGE",
        name: "Linen Napkin - Sage",
        offers: { price: "12.00", priceCurrency: "EUR" },
      },
      {
        "@type": "Product",
        sku: "NAP-RUST",
        name: "Linen Napkin - Rust",
        offers: { price: "12.00", priceCurrency: "EUR" },
      },
    ],
  }));
  const reading = extractJsonLd(doc, new URL("https://shop.example.com/products/napkin"));
  assertEquals(reading?.isGroup, true);
  assertEquals(reading?.fields.title, "Linen Napkin");
  assertEquals(reading?.fields.imageURL, "https://shop.example.com/napkin.jpg");
  assertEquals(reading?.fields.price, 12);
  assertEquals(reading?.fields.currency, "EUR");
});

Deno.test("a variant named by its sku in the path is the product", () => {
  const doc = parseHtml(jsonLdPage({
    "@type": "Product",
    name: "Linen Napkin",
    hasVariant: [
      { "@type": "Product", sku: "NAP-SAGE", name: "Linen Napkin - Sage", offers: { price: 12 } },
      { "@type": "Product", sku: "NAP-RUST", name: "Linen Napkin - Rust", offers: { price: 14 } },
    ],
  }));
  const reading = extractJsonLd(doc, new URL("https://shop.example.com/napkin/NAP-RUST"));
  assertEquals(reading?.fields.title, "Linen Napkin - Rust");
  assertEquals(reading?.fields.price, 14);
});

Deno.test("a numeric json-ld price with three decimals is not read as thousands", () => {
  const doc = parseHtml(jsonLdPage({
    "@type": "Product",
    name: "Tea Tin",
    offers: { price: 16.807, priceCurrency: "EUR" },
  }));
  assertEquals(extractJsonLd(doc, new URL("https://shop.example.com/tea"))?.fields.price, 16.81);
});

Deno.test("fields never mix across two different json-ld products", () => {
  const doc = parseHtml(`<html><head>
    <script type="application/ld+json">{"@type":"Product","name":"Main Vase"}</script>
    <script type="application/ld+json">{"@type":"Product","name":"Other Vase",
      "offers":{"price":"19.00","priceCurrency":"EUR"}}</script>
  </head></html>`);
  const reading = extractJsonLd(doc, new URL("https://shop.example.com/main-vase"));
  assertEquals(reading?.fields.title, "Main Vase");
  assertEquals(reading?.fields.price, null);
});

Deno.test("a product inside an item list is a list entry, not the page's product", () => {
  const doc = parseHtml(`<html><head>
    <script type="application/ld+json">{"@type":"ItemList","itemListElement":[
      {"@type":"Product","name":"Related Mug","offers":{"price":"9.00","priceCurrency":"EUR"}}
    ]}</script>
    <script type="application/ld+json">{"@type":"Product","name":"Main Vase",
      "offers":{"price":"129.00","priceCurrency":"EUR"}}</script>
  </head></html>`);
  const reading = extractJsonLd(doc, new URL("https://shop.example.com/main-vase"));
  assertEquals(reading?.fields.title, "Main Vase");
  assertEquals(reading?.fields.price, 129);
});

Deno.test("a second description of the same product fills in what the first left out", () => {
  const doc = parseHtml(`<html><head>
    <script type="application/ld+json">{"@type":"Product","name":"Main Vase",
      "aggregateRating":{"@type":"AggregateRating","ratingValue":4.8,"reviewCount":12}}</script>
    <script type="application/ld+json">{"@type":"Product","name":"Main Vase",
      "image":"https://shop.example.com/vase.jpg","offers":{"price":"129.00","priceCurrency":"EUR"}}</script>
  </head></html>`);
  const reading = extractJsonLd(doc, new URL("https://shop.example.com/main-vase"));
  assertEquals(reading?.fields.title, "Main Vase");
  assertEquals(reading?.fields.price, 129);
  assertEquals(reading?.fields.currency, "EUR");
  assertEquals(reading?.fields.imageURL, "https://shop.example.com/vase.jpg");
});

Deno.test("a group is never filled in from another node, even one with the same name", () => {
  const doc = parseHtml(`<html><head>
    <script type="application/ld+json">{"@type":"ProductGroup","name":"Tee",
      "hasVariant":[{"@type":"Product","sku":"TEE-S"},{"@type":"Product","sku":"TEE-M"}]}</script>
    <script type="application/ld+json">{"@type":"Product","name":"Tee",
      "offers":{"price":"25.00","priceCurrency":"USD"}}</script>
  </head></html>`);
  const reading = extractJsonLd(doc, new URL("https://shop.example.com/tee"));
  assertEquals(reading?.fields.title, "Tee");
  assertEquals(reading?.fields.price, null);
});

Deno.test("a group's own offer is its price when no variant carries one", () => {
  const doc = parseHtml(jsonLdPage({
    "@type": "Product",
    name: "Tee",
    offers: { "@type": "Offer", price: "20.00", priceCurrency: "USD" },
    hasVariant: [
      { "@type": "Product", sku: "TEE-S", name: "Tee - S" },
      { "@type": "Product", sku: "TEE-M", name: "Tee - M" },
    ],
  }));
  const unnamed = extractJsonLd(doc, new URL("https://shop.example.com/tee"));
  assertEquals(unnamed?.fields.title, "Tee");
  assertEquals(unnamed?.fields.price, 20);
  assertEquals(unnamed?.fields.currency, "USD");
  const named = extractJsonLd(doc, new URL("https://shop.example.com/tee/TEE-M"));
  assertEquals(named?.fields.title, "Tee - M");
  assertEquals(named?.fields.price, 20);
});

Deno.test("a group's own price range gives no price, a range of one price gives that price", () => {
  const group = (lowPrice: string, highPrice: string) =>
    parseHtml(jsonLdPage({
      "@type": "ProductGroup",
      name: "Linen Napkin",
      offers: { "@type": "AggregateOffer", lowPrice, highPrice, priceCurrency: "EUR" },
      hasVariant: [{ "@type": "Product", sku: "NAP-SAGE" }, {
        "@type": "Product",
        sku: "NAP-RUST",
      }],
    }));
  const link = new URL("https://shop.example.com/napkin");
  assertEquals(extractJsonLd(group("10.00", "14.00"), link)?.fields.price, null);
  assertEquals(extractJsonLd(group("12.00", "12.00"), link)?.fields.price, 12);
});

Deno.test("a group's own offer is not read when its variants carry prices", () => {
  const doc = parseHtml(jsonLdPage({
    "@type": "ProductGroup",
    name: "Linen Napkin",
    offers: { "@type": "Offer", price: "12.00", priceCurrency: "EUR" },
    hasVariant: [
      { "@type": "Product", sku: "NAP-SAGE", offers: { price: "12.00", priceCurrency: "EUR" } },
      { "@type": "Product", sku: "NAP-RUST", offers: { price: "14.00", priceCurrency: "EUR" } },
    ],
  }));
  assertEquals(
    extractJsonLd(doc, new URL("https://shop.example.com/napkin"))?.fields.price,
    null,
  );
});
