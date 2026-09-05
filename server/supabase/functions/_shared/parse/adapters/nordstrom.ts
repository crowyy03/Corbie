import type { HTMLDocument } from "../../html.ts";
import type { Adapter } from "./adapter.ts";
import { extractBySelectors } from "./adapter.ts";
import type { ProductFields } from "../types.ts";

export const nordstromAdapter: Adapter = {
  source: "nordstrom",
  matches: (host) => host === "nordstrom.com" || host.endsWith(".nordstrom.com"),
  extract(doc: HTMLDocument): ProductFields {
    return extractBySelectors(doc, {
      title: ['h1[itemprop="name"]', '[data-testid="product-title"]', "h1"],
      price: ['[data-testid="ProductPrice"]', '[itemprop="price"]', ".product-page-price"],
      priceAttribute: { selectors: ['[itemprop="price"]'], name: "content" },
      image: ['[data-testid="product-image"] img', "picture img", 'img[itemprop="image"]'],
      imageAttributes: ["src", "data-src"],
      brand: ['[itemprop="brand"]', '[data-testid="product-brand"]'],
    });
  },
};
