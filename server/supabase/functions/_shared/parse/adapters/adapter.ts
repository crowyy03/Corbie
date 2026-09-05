import { attrOfAny, type HTMLDocument, textOfAny } from "../../html.ts";
import { parsePrice } from "../price.ts";
import { emptyFields, type ParseSource, type ProductFields } from "../types.ts";

export interface Adapter {
  source: ParseSource;
  matches(host: string): boolean;
  extract(doc: HTMLDocument): ProductFields;
}

export interface SelectorSet {
  title: string[];
  price: string[];
  priceAttribute?: { selectors: string[]; name: string };
  image: string[];
  imageAttributes?: string[];
  brand?: string[];
}

export function extractBySelectors(doc: HTMLDocument, selectors: SelectorSet): ProductFields {
  const title = textOfAny(doc, selectors.title);
  const brand = selectors.brand ? textOfAny(doc, selectors.brand) : null;

  let priceText = textOfAny(doc, selectors.price);
  if (!priceText && selectors.priceAttribute) {
    priceText = attrOfAny(doc, selectors.priceAttribute.selectors, selectors.priceAttribute.name);
  }
  const price = parsePrice(priceText);

  const imageAttributes = selectors.imageAttributes ?? ["src"];
  let imageURL: string | null = null;
  for (const attribute of imageAttributes) {
    imageURL = attrOfAny(doc, selectors.image, attribute);
    if (imageURL) break;
  }

  return {
    ...emptyFields,
    title,
    price: price?.amount ?? null,
    currency: price?.currency ?? null,
    imageURL,
    author: brand,
  };
}
