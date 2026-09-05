import type { HTMLDocument } from "../../html.ts";
import type { Adapter } from "./adapter.ts";
import { extractBySelectors } from "./adapter.ts";
import type { ProductFields } from "../types.ts";

export const sephoraAdapter: Adapter = {
  source: "sephora",
  matches: (host) => host === "sephora.com" || host.endsWith(".sephora.com"),
  extract(doc: HTMLDocument): ProductFields {
    return extractBySelectors(doc, {
      title: ['[data-at="product_name"]', "h1 span", "h1"],
      price: ['[data-at="price_usd"]', '[data-comp="Price "] b', '[data-at="price"]'],
      image: ['[data-comp="ProductImage "] img', ".css-1rovmyu img", "picture img"],
      imageAttributes: ["src", "data-src"],
      brand: ['[data-at="brand_name"]'],
    });
  },
};
