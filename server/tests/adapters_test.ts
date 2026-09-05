import { assertEquals } from "@std/assert";
import { extractFields, sourceForHost } from "../supabase/functions/_shared/parse/index.ts";
import type { ProductFields } from "../supabase/functions/_shared/parse/types.ts";

const fixtureDir = new URL("./fixtures/", import.meta.url);

async function fixture(name: string): Promise<string> {
  return await Deno.readTextFile(new URL(name, fixtureDir));
}

async function fields(name: string, host: string): Promise<ProductFields> {
  return extractFields(await fixture(name), host);
}

Deno.test("source is picked from the hostname", () => {
  assertEquals(sourceForHost("amazon.com"), "amazon");
  assertEquals(sourceForHost("amazon.co.uk"), "amazon");
  assertEquals(sourceForHost("target.com"), "target");
  assertEquals(sourceForHost("etsy.com"), "etsy");
  assertEquals(sourceForHost("sephora.com"), "sephora");
  assertEquals(sourceForHost("nordstrom.com"), "nordstrom");
  assertEquals(sourceForHost("zara.com"), "zara");
  assertEquals(sourceForHost("ikea.com"), "ikea");
  assertEquals(sourceForHost("instagram.com"), "instagram");
  assertEquals(sourceForHost("tiktok.com"), "tiktok");
  assertEquals(sourceForHost("kleinerladen.de"), "generic");
});

Deno.test("amazon adapter reads the product title block", async () => {
  const result = await fields("amazon.html", "amazon.com");
  assertEquals(result.title, "Hario V60 Ceramic Coffee Dripper, Size 02, White");
  assertEquals(result.price, 24.9);
  assertEquals(result.currency, "USD");
  assertEquals(result.imageURL, "https://m.media-amazon.com/images/I/71dripper._AC_SL1500_.jpg");
  assertEquals(result.author, "Visit the Hario Store");
});

Deno.test("target adapter reads the data-test attributes", async () => {
  const result = await fields("target.html", "target.com");
  assertEquals(result.title, "Stoneware Mug 16oz - Threshold");
  assertEquals(result.price, 8);
  assertEquals(result.currency, "USD");
  assertEquals(
    result.imageURL,
    "https://target.scene7.com/is/image/Target/GUEST_mug_main?wid=1200",
  );
  assertEquals(result.author, "Threshold");
});

Deno.test("etsy adapter reads the buy box", async () => {
  const result = await fields("etsy.html", "etsy.com");
  assertEquals(result.title, "Handmade Linen Apron in Sage");
  assertEquals(result.price, 42.5);
  assertEquals(result.currency, "GBP");
  assertEquals(result.imageURL, "https://i.etsystatic.com/il/full/apron_zoom.jpg");
  assertEquals(result.author, "NordicThreadStudio");
});

Deno.test("sephora adapter reads the product name and usd price", async () => {
  const result = await fields("sephora.html", "sephora.com");
  assertEquals(result.title, "Lip Sleeping Mask Intense Hydration with Vitamin C");
  assertEquals(result.price, 24);
  assertEquals(result.currency, "USD");
  assertEquals(result.imageURL, "https://www.sephora.com/productimages/sku/s2242466-main-zoom.jpg");
  assertEquals(result.author, "LANEIGE");
});

Deno.test("nordstrom adapter reads itemprop name and test id price", async () => {
  const result = await fields("nordstrom.html", "nordstrom.com");
  assertEquals(result.title, "The Perfect Vintage High Waist Jean");
  assertEquals(result.price, 138);
  assertEquals(result.currency, "USD");
  assertEquals(result.imageURL, "https://n.nordstrommedia.com/id/sr3/jean-main.jpeg?w=1200");
  assertEquals(result.author, "Madewell");
});

Deno.test("zara adapter reads the european money amount", async () => {
  const result = await fields("zara.html", "zara.com");
  assertEquals(result.title, "ABRIGO DE LANA CON CINTURÓN");
  assertEquals(result.price, 1299);
  assertEquals(result.currency, "EUR");
  assertEquals(result.imageURL, "https://static.zara.net/photos/abrigo-main.jpg");
});

Deno.test("ikea adapter joins name and description and reads the split price", async () => {
  const result = await fields("ikea.html", "ikea.com");
  assertEquals(result.title, "BILLY Bookcase, white");
  assertEquals(result.price, 69.99);
  assertEquals(result.currency, "USD");
  assertEquals(
    result.imageURL,
    "https://www.ikea.com/us/en/images/products/billy-bookcase-white.jpg",
  );
});

Deno.test("generic open graph page yields title, image and european price", async () => {
  const result = await fields("generic-og.html", "kleinerladen.de");
  assertEquals(result.title, "Keramikvase Nord, handgetöpfert");
  assertEquals(result.price, 1234.56);
  assertEquals(result.currency, "EUR");
  assertEquals(result.imageURL, "/media/vase-nord.jpg");
  assertEquals(result.author, "Kleiner Laden");
});

Deno.test("json-ld product wins over an empty open graph head", async () => {
  const result = await fields("generic-jsonld.html", "example.com");
  assertEquals(result.title, "Merino Wool Beanie");
  assertEquals(result.price, 39);
  assertEquals(result.currency, "CAD");
  assertEquals(result.imageURL, "https://cdn.example.com/beanie-1.jpg");
  assertEquals(result.author, "Northbound");
});
