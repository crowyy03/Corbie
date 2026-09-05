import type { HTMLDocument } from "../../html.ts";
import { isAmazonHost } from "../normalizeUrl.ts";
import type { Adapter } from "./adapter.ts";
import { extractBySelectors } from "./adapter.ts";
import type { ProductFields } from "../types.ts";

export const amazonAdapter: Adapter = {
  source: "amazon",
  matches: isAmazonHost,
  extract(doc: HTMLDocument): ProductFields {
    return extractBySelectors(doc, {
      title: ["#productTitle", "#title span", "h1#title"],
      price: [
        "#corePrice_feature_div .a-price .a-offscreen",
        "#corePriceDisplay_desktop_feature_div .a-price .a-offscreen",
        "#apex_desktop .a-price .a-offscreen",
        ".a-price .a-offscreen",
        "#priceblock_ourprice",
        "#priceblock_dealprice",
      ],
      image: ["#landingImage", "#imgTagWrapperId img", "#main-image", "#ebooksImgBlkFront"],
      imageAttributes: ["data-old-hires", "src"],
      brand: ["#bylineInfo", "#brand"],
    });
  },
};
