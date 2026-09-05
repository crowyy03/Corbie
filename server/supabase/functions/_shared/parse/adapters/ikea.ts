import { attrOfAny, type HTMLDocument, textOfAny } from "../../html.ts";
import { parsePrice } from "../price.ts";
import { emptyFields, type ProductFields } from "../types.ts";
import type { Adapter } from "./adapter.ts";

const screenReaderPrice = [
  ".pip-temp-price__sr-text",
  ".pip-price__sr-text",
  ".pip-price-package__main-price .pip-price__sr-text",
];

const integerParts = [".pip-temp-price__integer", ".pip-price__integer"];
const decimalParts = [".pip-temp-price__decimal", ".pip-price__decimal"];
const currencyParts = [".pip-temp-price__currency-symbol", ".pip-price__currency-symbol"];

function assemblePrice(doc: HTMLDocument): string | null {
  const whole = textOfAny(doc, integerParts);
  if (!whole) return null;
  const fraction = textOfAny(doc, decimalParts) ?? "";
  const symbol = textOfAny(doc, currencyParts) ?? "";
  return `${symbol}${whole}${fraction}`;
}

export const ikeaAdapter: Adapter = {
  source: "ikea",
  matches: (host) => host === "ikea.com" || host.endsWith(".ikea.com"),
  extract(doc: HTMLDocument): ProductFields {
    const title = textOfAny(doc, [
      ".pip-header-section__title--big",
      ".pip-header-section__description-text",
      "h1.pip-header-section__title",
      "h1",
    ]);
    const description = textOfAny(doc, [".pip-header-section__description-text"]);
    const priceText = textOfAny(doc, screenReaderPrice) ?? assemblePrice(doc);
    const price = parsePrice(priceText);
    const imageURL = attrOfAny(
      doc,
      [".pip-media-grid__media-image", ".pip-aspect-ratio-image__image", "picture img"],
      "src",
    );

    const fullTitle = title && description && description !== title
      ? `${title} ${description}`
      : title;

    return {
      ...emptyFields,
      title: fullTitle,
      price: price?.amount ?? null,
      currency: price?.currency ?? null,
      imageURL,
    };
  },
};
