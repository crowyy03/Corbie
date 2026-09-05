import type { HTMLDocument } from "../../html.ts";
import type { Adapter } from "./adapter.ts";
import { extractBySelectors } from "./adapter.ts";
import type { ProductFields } from "../types.ts";

export const etsyAdapter: Adapter = {
  source: "etsy",
  matches: (host) => host === "etsy.com" || host.endsWith(".etsy.com"),
  extract(doc: HTMLDocument): ProductFields {
    return extractBySelectors(doc, {
      title: ["h1[data-buy-box-listing-title]", "#listing-page-cart h1", "h1.wt-text-body-01"],
      price: [
        '[data-buy-box-region="price"] p.wt-text-title-larger',
        '[data-selector="price-only"]',
        '[data-buy-box-region="price"] .wt-text-title-03',
      ],
      priceAttribute: { selectors: ['meta[itemprop="price"]'], name: "content" },
      image: [
        "img[data-src-zoom-image]",
        "#listing-page-image-carousel img",
        "img.wt-max-width-full",
      ],
      imageAttributes: ["data-src-zoom-image", "src", "data-src"],
      brand: ["[data-shop-name]", "#listing-page-shop-name"],
    });
  },
};
