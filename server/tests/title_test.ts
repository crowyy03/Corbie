import { assertEquals } from "@std/assert";
import { hostName, stripSiteName } from "../supabase/functions/_shared/parse/title.ts";

Deno.test("a trailing site name from og:site_name or the host is cut from the title", () => {
  assertEquals(
    stripSiteName("Apple AirPods 4 - Walmart.com", "Walmart.com", "walmart.com"),
    "Apple AirPods 4",
  );
  assertEquals(
    stripSiteName("Unisex SUPIMA® Cotton T-Shirt | UNIQLO US", "UNIQLO", "uniqlo.com"),
    "Unisex SUPIMA® Cotton T-Shirt",
  );
  assertEquals(
    stripSiteName("Men’s Black Regular Fit T-shirt | H&M US", "H&M", "www2.hm.com"),
    "Men’s Black Regular Fit T-shirt",
  );
  assertEquals(
    stripSiteName(
      "Stanley 30 oz Stainless Steel H2.0 Flowstate Quencher Tumbler : Target",
      null,
      "target.com",
    ),
    "Stanley 30 oz Stainless Steel H2.0 Flowstate Quencher Tumbler",
  );
  assertEquals(
    stripSiteName(
      "Borsa Again Tela Monogram - Borse da Donna M25877 | LOUIS VUITTON",
      null,
      "it.louisvuitton.com",
    ),
    "Borsa Again Tela Monogram - Borse da Donna M25877",
  );
  assertEquals(stripSiteName("Kettle - Argos", null, "argos.co.uk"), "Kettle");
  assertEquals(
    stripSiteName("Air Force 1 Low Men's Shoes. Nike.com", null, "www.nike.com"),
    "Air Force 1 Low Men's Shoes",
  );
  assertEquals(stripSiteName("1460 Boots | Dr. Martens", null, "drmartens.com"), "1460 Boots");
});

Deno.test("a last segment that is not the site stays in the title", () => {
  assertEquals(
    stripSiteName("Regular Fit T-shirt - White", "H&M", "www2.hm.com"),
    "Regular Fit T-shirt - White",
  );
  assertEquals(stripSiteName("Candle - Hmmm", "H&M", "hm.com"), "Candle - Hmmm");
  assertEquals(stripSiteName("Case - Apple Watch", "Apple", "apple.com"), "Case - Apple Watch");
  assertEquals(stripSiteName("Walmart.com", "Walmart.com", "walmart.com"), "Walmart.com");
  assertEquals(stripSiteName("Star Wars: The Mug", null, "starwars.com"), "Star Wars: The Mug");
  assertEquals(
    stripSiteName("Dr. Martens 1460 Boots", null, "drmartens.com"),
    "Dr. Martens 1460 Boots",
  );
  assertEquals(stripSiteName("Vol. 2. Nike", null, "books.example"), "Vol. 2. Nike");
});

Deno.test("the host's brand is the label under the public suffix", () => {
  assertEquals(hostName("www2.hm.com"), { brand: "hm", topLevel: "com" });
  assertEquals(hostName("amazon.co.uk"), { brand: "amazon", topLevel: "uk" });
  assertEquals(hostName("it.louisvuitton.com"), { brand: "louisvuitton", topLevel: "com" });
  assertEquals(hostName("kleinerladen.de"), { brand: "kleinerladen", topLevel: "de" });
});
