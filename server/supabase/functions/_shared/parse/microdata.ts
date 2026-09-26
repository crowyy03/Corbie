import { collapse, type Element, type HTMLDocument } from "../html.ts";
import { detectCurrency, normalizeCurrencyCode, parseAmount } from "./price.ts";
import { emptyFields, type ProductFields } from "./types.ts";

const offerTypes = new Set(["Offer", "AggregateOffer"]);
const pageTypes = new Set(["WebPage", "ItemPage"]);

function itemTypes(item: Element): string[] {
  return (item.getAttribute("itemtype") ?? "").split(/\s+/)
    .map((type) => type.replace(/^https?:\/\/schema\.org\//i, ""))
    .filter((type) => type.length > 0);
}

function isProductItem(item: Element): boolean {
  return itemTypes(item).includes("Product");
}

function isOfferItem(item: Element): boolean {
  return itemTypes(item).some((type) => offerTypes.has(type));
}

function isPageItem(item: Element): boolean {
  return itemTypes(item).some((type) => pageTypes.has(type));
}

function enclosingItems(element: Element): Element[] {
  const items: Element[] = [];
  for (let node = element.parentElement; node; node = node.parentElement) {
    if (node.hasAttribute("itemscope")) items.push(node);
  }
  return items;
}

function pageProducts(doc: HTMLDocument): Element[] {
  return [...doc.querySelectorAll("[itemscope]")]
    .filter((item: Element) => isProductItem(item) && enclosingItems(item).every(isPageItem));
}

function describesProduct(element: Element, product: Element | null): boolean {
  const items = enclosingItems(element);
  if (product === null) return items.every((item) => isOfferItem(item) || isPageItem(item));
  const depth = items.indexOf(product);
  return depth >= 0 && items.slice(0, depth).every(isOfferItem);
}

function declaredValues(doc: HTMLDocument, property: string, product: Element | null): string[] {
  return [...doc.querySelectorAll(`[itemprop="${property}"]`)]
    .filter((element: Element) => describesProduct(element, product))
    .map((element: Element) => element.getAttribute("content") ?? element.textContent)
    .map((value) => collapse(value ?? ""))
    .filter((value) => value.length > 0);
}

function agreed<T>(values: T[]): T | null {
  if (values.length === 0) return null;
  return values.every((value) => value === values[0]) ? values[0] : null;
}

export function extractMicrodata(doc: HTMLDocument): ProductFields {
  const products = pageProducts(doc);
  if (products.length > 1) return { ...emptyFields };
  const product = products[0] ?? null;

  const priceTexts = declaredValues(doc, "price", product);
  const amounts = priceTexts.map(parseAmount);
  const price = amounts.includes(null) ? null : agreed(amounts);
  if (price === null) return { ...emptyFields };

  const currency =
    agreed(declaredValues(doc, "priceCurrency", product).map(normalizeCurrencyCode)) ??
      agreed(priceTexts.map(detectCurrency));
  return { ...emptyFields, price, currency };
}
