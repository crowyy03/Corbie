import type { HTMLDocument } from "../../html.ts";
import type { Adapter } from "./adapter.ts";
import { extractBySelectors } from "./adapter.ts";
import type { ProductFields } from "../types.ts";

export const targetAdapter: Adapter = {
  source: "target",
  matches: (host) => host === "target.com" || host.endsWith(".target.com"),
  extract(doc: HTMLDocument): ProductFields {
    return extractBySelectors(doc, {
      title: ['h1[data-test="product-title"]', '[data-test="product-title"]', "h1"],
      price: [
        '[data-test="product-price"]',
        '[data-test="product-price-value"]',
        '[data-test="current-price"] span',
      ],
      image: ['[data-test="image-gallery-item-0"] img', "picture img", "img[alt][srcset]"],
      imageAttributes: ["src", "data-src"],
      brand: ['[data-test="product-brand"]'],
    });
  },
};
