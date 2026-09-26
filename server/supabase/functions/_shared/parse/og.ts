import { attrOfAny, type HTMLDocument } from "../html.ts";
import { normalizeCurrencyCode, parseAmount, parsePrice } from "./price.ts";
import { emptyFields, type ProductFields } from "./types.ts";

const titleSelectors = [
  'meta[property="og:title"]',
  'meta[name="og:title"]',
  'meta[name="twitter:title"]',
  'meta[property="twitter:title"]',
];

const imageSelectors = [
  'meta[property="og:image:secure_url"]',
  'meta[property="og:image"]',
  'meta[name="og:image"]',
  'meta[name="twitter:image"]',
  'meta[property="twitter:image"]',
  'meta[name="twitter:image:src"]',
];

const amountSelectors = [
  'meta[property="product:price:amount"]',
  'meta[property="og:price:amount"]',
  'meta[name="og:price:amount"]',
];

const currencySelectors = [
  'meta[property="product:price:currency"]',
  'meta[property="og:price:currency"]',
  'meta[name="og:price:currency"]',
];

const authorSelectors = [
  'meta[name="author"]',
  'meta[property="og:site_name"]',
  'meta[name="twitter:creator"]',
];

const typeSelectors = ['meta[property="og:type"]', 'meta[name="og:type"]'];
const productTypes = new Set(["product", "product.item"]);

export function declaresProduct(doc: HTMLDocument): boolean {
  const type = attrOfAny(doc, typeSelectors, "content");
  return type !== null && productTypes.has(type.toLowerCase());
}

export function readSiteName(doc: HTMLDocument): string | null {
  return attrOfAny(doc, ['meta[property="og:site_name"]', 'meta[name="og:site_name"]'], "content");
}

export function extractOpenGraph(doc: HTMLDocument): ProductFields {
  const title = attrOfAny(doc, titleSelectors, "content");
  const imageURL = attrOfAny(doc, imageSelectors, "content");
  const rawAmount = attrOfAny(doc, amountSelectors, "content");
  const rawCurrency = attrOfAny(doc, currencySelectors, "content");
  const author = attrOfAny(doc, authorSelectors, "content");

  const price = rawAmount ? parseAmount(rawAmount) : null;
  const currency = normalizeCurrencyCode(rawCurrency) ??
    (rawAmount ? parsePrice(rawAmount)?.currency ?? null : null);

  return {
    ...emptyFields,
    title,
    price,
    currency: price === null ? null : currency,
    imageURL,
    author,
  };
}
