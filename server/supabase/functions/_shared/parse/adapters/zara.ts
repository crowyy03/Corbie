import type { HTMLDocument } from "../../html.ts";
import type { Adapter } from "./adapter.ts";
import { extractBySelectors } from "./adapter.ts";
import type { ProductFields } from "../types.ts";

export const zaraAdapter: Adapter = {
  source: "zara",
  matches: (host) => host === "zara.com" || host.endsWith(".zara.com"),
  extract(doc: HTMLDocument): ProductFields {
    return extractBySelectors(doc, {
      title: [".product-detail-info__header-name", "h1.product-detail-info__header-name", "h1"],
      price: [
        ".price__amount-current .money-amount__main",
        ".money-amount__main",
        ".product-detail-info__price .price-current__amount",
      ],
      image: [".product-detail-images__image", ".media-image__image", "picture img"],
      imageAttributes: ["src", "data-src"],
    });
  },
};
