import { collapse, type HTMLDocument } from "../html.ts";
import { normalizeCurrencyCode, parseAmount } from "./price.ts";
import { emptyFields, type ProductFields } from "./types.ts";

type Json = Record<string, unknown>;

function isObject(value: unknown): value is Json {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function typesOf(node: Json): string[] {
  const raw = node["@type"];
  const list = Array.isArray(raw) ? raw : [raw];
  return list.filter((entry): entry is string => typeof entry === "string");
}

function walk(value: unknown, visit: (node: Json) => void): void {
  if (Array.isArray(value)) {
    for (const entry of value) walk(entry, visit);
    return;
  }
  if (!isObject(value)) return;
  visit(value);
  for (const key of ["@graph", "mainEntity", "itemListElement", "hasVariant"]) {
    if (key in value) walk(value[key], visit);
  }
}

function readImage(value: unknown): string | null {
  if (typeof value === "string") return value.trim() || null;
  if (Array.isArray(value)) {
    for (const entry of value) {
      const found = readImage(entry);
      if (found) return found;
    }
    return null;
  }
  if (isObject(value)) return readImage(value.url ?? value.contentUrl);
  return null;
}

function readText(value: unknown): string | null {
  if (typeof value === "string") return collapse(value) || null;
  if (Array.isArray(value)) return readText(value[0]);
  if (isObject(value)) return readText(value.name);
  return null;
}

function readOffer(value: unknown): { price: number | null; currency: string | null } {
  if (Array.isArray(value)) {
    for (const entry of value) {
      const found = readOffer(entry);
      if (found.price !== null) return found;
    }
    return { price: null, currency: null };
  }
  if (!isObject(value)) return { price: null, currency: null };

  if (Array.isArray(value.offers) || isObject(value.offers)) {
    const nested = readOffer(value.offers);
    if (nested.price !== null) return nested;
  }

  const rawPrice = value.price ?? value.lowPrice ?? value.highPrice;
  const priceText = typeof rawPrice === "number"
    ? String(rawPrice)
    : typeof rawPrice === "string"
    ? rawPrice
    : null;
  const spec = value.priceSpecification;
  if (priceText === null && isObject(spec)) return readOffer(spec);

  return {
    price: priceText ? parseAmount(priceText) : null,
    currency: normalizeCurrencyCode(
      typeof value.priceCurrency === "string" ? value.priceCurrency : null,
    ),
  };
}

export function extractJsonLd(doc: HTMLDocument): ProductFields {
  let result: ProductFields = { ...emptyFields };

  for (const script of doc.querySelectorAll('script[type="application/ld+json"]')) {
    const raw = script.textContent;
    if (!raw || raw.trim().length === 0) continue;
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      continue;
    }
    walk(parsed, (node) => {
      if (result.price !== null && result.title !== null && result.imageURL !== null) return;
      if (!typesOf(node).includes("Product")) return;

      const offer = readOffer(node.offers);
      const title = readText(node.name);
      const image = readImage(node.image);
      const brand = readText(node.brand);

      result = {
        title: result.title ?? title,
        price: result.price ?? offer.price,
        currency: result.price !== null ? result.currency : offer.currency,
        imageURL: result.imageURL ?? image,
        author: result.author ?? brand,
      };
    });
  }

  if (result.price === null) result.currency = null;
  return result;
}
