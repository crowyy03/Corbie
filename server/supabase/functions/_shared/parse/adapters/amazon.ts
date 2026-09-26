import { type Element, type HTMLDocument, textOfAny } from "../../html.ts";
import { isAmazonHost } from "../normalizeUrl.ts";
import {
  acceptAmount,
  hasNoMinorUnit,
  normalizeCurrencyCode,
  parsePrice,
  type Price,
  showsMinorUnit,
} from "../price.ts";
import type { Adapter } from "./adapter.ts";
import { extractBySelectors } from "./adapter.ts";
import type { ProductFields } from "../types.ts";

const ownPriceBlocks = [
  "#corePrice_mobile_feature_div",
  "#corePrice_feature_div",
  "#corePriceDisplay_desktop_feature_div",
  "#apex_desktop",
];

const legacyPriceIds = ["#priceblock_ourprice", "#priceblock_dealprice"];

function ownPriceElement(doc: HTMLDocument): Element | null {
  for (const selector of ownPriceBlocks) {
    const price = doc.querySelector(selector)?.querySelector(".a-price:not(.a-text-price)");
    if (price) return price;
  }
  return null;
}

function amountFromParts(whole: string, fraction: string): number | null {
  const wholeDigits = whole.replace(/\D/g, "");
  const fractionDigits = fraction.replace(/\D/g, "");
  if (wholeDigits.length === 0) return null;
  return acceptAmount(Number(fractionDigits ? `${wholeDigits}.${fractionDigits}` : wholeDigits));
}

function readPriceText(text: string | null): Price | null {
  const price = parsePrice(text);
  if (price === null || text === null) return null;
  return showsMinorUnit(text) || hasNoMinorUnit(price.currency) ? price : null;
}

function readShownPrice(price: Element): Price | null {
  const offscreen = price.querySelector(".a-offscreen")?.textContent ?? null;
  const whole = price.querySelector(".a-price-whole")?.textContent;
  if (!whole) return readPriceText(offscreen);

  const amount = amountFromParts(
    whole,
    price.querySelector(".a-price-fraction")?.textContent ?? "",
  );
  if (amount === null) return null;
  const symbol = price.querySelector(".a-price-symbol")?.textContent ?? null;
  return {
    amount,
    currency: normalizeCurrencyCode(symbol) ?? parsePrice(offscreen)?.currency ?? null,
  };
}

function readOwnPrice(doc: HTMLDocument): Price | null {
  const element = ownPriceElement(doc);
  return (element ? readShownPrice(element) : null) ??
    readPriceText(textOfAny(doc, legacyPriceIds));
}

export const amazonAdapter: Adapter = {
  source: "amazon",
  matches: isAmazonHost,
  ownsPrice: true,
  extract(doc: HTMLDocument): ProductFields {
    const fields = extractBySelectors(doc, {
      title: ["#productTitle", "#title span", "h1#title"],
      price: [],
      image: ["#landingImage", "#imgTagWrapperId img", "#main-image", "#ebooksImgBlkFront"],
      imageAttributes: ["data-old-hires", "src"],
      brand: ["#bylineInfo", "#brand"],
    });
    const price = readOwnPrice(doc);
    return { ...fields, price: price?.amount ?? null, currency: price?.currency ?? null };
  },
};
