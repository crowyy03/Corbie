import { assertEquals } from "@std/assert";
import { extractFields, sourceForHost } from "../supabase/functions/_shared/parse/index.ts";
import type { ProductFields } from "../supabase/functions/_shared/parse/types.ts";

const fixtureDir = new URL("./fixtures/", import.meta.url);

async function fixture(name: string): Promise<string> {
  return await Deno.readTextFile(new URL(name, fixtureDir));
}

async function fields(name: string, host: string): Promise<ProductFields> {
  return extractFields(await fixture(name), new URL(`https://${host}/`)).fields;
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
  assertEquals(sourceForHost("uniqlo.com"), "uniqlo");
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

Deno.test("amazon gives no price when the product's own price block is empty, whatever the carousel shows", async () => {
  const reading = extractFields(
    await fixture("amazon-mobile-deliver-to-finland.html"),
    new URL("https://www.amazon.com/dp/B0CHWRXH8B"),
  );
  assertEquals(reading.fields.price, null);
  assertEquals(reading.fields.currency, null);
  assertEquals(reading.priceFrom, "none");
  assertEquals(
    reading.fields.title,
    "Apple AirPods Pro (2nd Generation) Wireless Ear Buds with USB-C Charging, Up to 2X More Active Noise Cancelling Bluetooth Headphones, Transparency Mode, Adaptive, Personalized Spatial Audio, White",
  );
  assertEquals(
    reading.fields.imageURL,
    "https://m.media-amazon.com/images/I/51NRGHU2NoL._AC_UF350,350_QL50_.jpg",
  );
});

Deno.test("amazon reads its own mobile price from the shown parts, not the text that lost its decimal point", async () => {
  const result = await fields("amazon-mobile-own-price.html", "amazon.com");
  assertEquals(result.price, 14.03);
  assertEquals(result.currency, "EUR");
});

function amazonMobilePage(ownPrice: string, rest = ""): string {
  return `<html><head>${rest}</head><body>
    <h1 id="title">Apple AirPods Pro (2nd Generation)</h1>
    <img id="main-image" src="https://m.media-amazon.com/images/I/51NRGHU2NoL.jpg">
    <div id="corePrice_mobile_feature_div">${ownPrice}</div>
  </body></html>`;
}

const amazonLink = new URL("https://www.amazon.com/dp/B0CHWRXH8B");

Deno.test("amazon takes no price from its own hidden text when the text lost its decimal point", () => {
  const partsless = amazonMobilePage(
    '<span class="a-price priceToPay"><span class="a-offscreen">EUR1403</span></span>',
  );
  const reading = extractFields(partsless, amazonLink);
  assertEquals(reading.fields.price, null);
  assertEquals(reading.priceFrom, "none");

  const legacy = amazonMobilePage("").replace(
    "</body>",
    '<span id="priceblock_ourprice">EUR1403</span></body>',
  );
  assertEquals(extractFields(legacy, amazonLink).fields.price, null);
});

Deno.test("amazon reads its own hidden text when it shows the decimals or the currency has none", () => {
  const withDecimals = amazonMobilePage(
    '<span class="a-price"><span class="a-offscreen">EUR14,03</span></span>',
  );
  const euro = extractFields(withDecimals, amazonLink);
  assertEquals(euro.fields.price, 14.03);
  assertEquals(euro.fields.currency, "EUR");

  const yen = amazonMobilePage(
    '<span class="a-price"><span class="a-offscreen">¥1,234</span></span>',
  );
  const read = extractFields(yen, new URL("https://www.amazon.co.jp/dp/B0CHWRXH8B"));
  assertEquals(read.fields.price, 1234);
  assertEquals(read.fields.currency, "JPY");
});

Deno.test("amazon's price comes only from its own block: carousel microdata, og and json-ld are not asked", () => {
  const pageWide = [
    ["", '<span itemprop="price" content="14.03">EUR14.03</span>'],
    ['<meta property="product:price:amount" content="1403">', ""],
    [
      '<script type="application/ld+json">{"@type":"Product","name":"AirPods","offers":{"price":"1403","priceCurrency":"EUR"}}</script>',
      "",
    ],
  ];
  for (const [head, body] of pageWide) {
    const html = amazonMobilePage("", head).replace("</body>", `${body}</body>`);
    const reading = extractFields(html, amazonLink);
    assertEquals(reading.fields.price, null, head || body);
    assertEquals(reading.fields.currency, null, head || body);
    assertEquals(reading.priceFrom, "none", head || body);
  }
});

Deno.test("uniqlo adapter reads the price of the product the link names from the preloaded state", async () => {
  const reading = extractFields(
    await fixture("uniqlo.html"),
    new URL("https://www.uniqlo.com/us/en/products/E455365-000/00"),
  );
  assertEquals(reading.fields.price, 24.9);
  assertEquals(reading.fields.currency, "USD");
  assertEquals(reading.priceFrom, "adapter");
  assertEquals(reading.fields.title, "Unisex SUPIMA® Cotton T-Shirt");
});

const uniqloLink = new URL("https://www.uniqlo.com/us/en/products/E455365-000/00");

Deno.test("a uniqlo promo price wins over the base price", async () => {
  const html = (await fixture("uniqlo.html")).replace(
    '"promo":null',
    '"promo":{"currency":{"code":"USD","symbol":"$"},"value":19.9}',
  );
  const reading = extractFields(html, uniqloLink);
  assertEquals(reading.fields.price, 19.9);
  assertEquals(reading.fields.currency, "USD");
});

Deno.test("a uniqlo promo that cannot be read gives no price, neither the base one nor a page tag's", async () => {
  const html = (await fixture("uniqlo.html"))
    .replace('"promo":null', '"promo":{"currency":{"code":"USD"},"value":"sale"}')
    .replace("</head>", '<meta property="product:price:amount" content="24.90"></head>');
  const reading = extractFields(html, uniqloLink);
  assertEquals(reading.fields.price, null);
  assertEquals(reading.priceFrom, "none");
});

Deno.test("a uniqlo link to another product takes no price from this page's state", async () => {
  const reading = extractFields(
    await fixture("uniqlo.html"),
    new URL("https://www.uniqlo.com/us/en/products/E999999-000/00"),
  );
  assertEquals(reading.fields.price, null);
  assertEquals(reading.fields.currency, null);
});
