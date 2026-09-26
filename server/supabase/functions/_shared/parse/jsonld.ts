import { collapse, type HTMLDocument } from "../html.ts";
import { hostOf, normalizeUrl } from "./normalizeUrl.ts";
import { acceptAmount, normalizeCurrencyCode, parseAmount } from "./price.ts";
import type { ProductFields } from "./types.ts";

type Json = Record<string, unknown>;

interface Offer {
  price: number | null;
  currency: string | null;
}

const noOffer: Offer = { price: null, currency: null };

function isObject(value: unknown): value is Json {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function listOf(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [value];
}

function typesOf(node: Json): string[] {
  return listOf(node["@type"]).filter((entry): entry is string => typeof entry === "string");
}

function isProduct(node: unknown): node is Json {
  return isObject(node) && typesOf(node).includes("Product");
}

function isProductOrGroup(node: Json): boolean {
  const types = typesOf(node);
  return types.includes("Product") || types.includes("ProductGroup");
}

function productNodesIn(value: unknown): Json[] {
  if (Array.isArray(value)) return value.flatMap(productNodesIn);
  if (!isObject(value)) return [];
  if (isProductOrGroup(value)) return [value];
  return ["@graph", "mainEntity"].flatMap((key) => key in value ? productNodesIn(value[key]) : []);
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

function readOffer(value: unknown): Offer {
  if (Array.isArray(value)) {
    for (const entry of value) {
      const found = readOffer(entry);
      if (found.price !== null) return found;
    }
    return noOffer;
  }
  if (!isObject(value)) return noOffer;

  if (Array.isArray(value.offers) || isObject(value.offers)) {
    const nested = readOffer(value.offers);
    if (nested.price !== null) return nested;
  }

  const rawPrice = value.price ?? value.lowPrice ?? value.highPrice;
  if (typeof rawPrice !== "number" && typeof rawPrice !== "string") {
    return isObject(value.priceSpecification) ? readOffer(value.priceSpecification) : noOffer;
  }

  const price = typeof rawPrice === "number" ? acceptAmount(rawPrice) : parseAmount(rawPrice);
  return {
    price,
    currency: price === null ? null : normalizeCurrencyCode(
      typeof value.priceCurrency === "string" ? value.priceCurrency : null,
    ),
  };
}

function pageKey(address: string, base: URL): string | null {
  try {
    const url = new URL(normalizeUrl(new URL(address, base).toString()));
    return `${hostOf(url)}${url.pathname}${url.search}`;
  } catch {
    return null;
  }
}

function linkTokens(link: URL): Set<string> {
  const tokens = new Set<string>();
  for (const segment of link.pathname.split("/")) {
    let decoded: string;
    try {
      decoded = decodeURIComponent(segment).toLowerCase();
    } catch {
      continue;
    }
    if (decoded.length === 0) continue;
    tokens.add(decoded);
    for (const piece of decoded.split(".")) if (piece.length > 0) tokens.add(piece);
  }
  return tokens;
}

function variantAddresses(variant: Json): string[] {
  const offerUrls = listOf(variant.offers).filter(isObject).map((offer) => offer.url);
  return [variant.url, variant["@id"], ...offerUrls]
    .filter((address): address is string => typeof address === "string");
}

function variantCodes(variant: Json): string[] {
  return [variant.sku, variant.mpn, variant.productID]
    .filter((code) => typeof code === "string" || typeof code === "number")
    .map((code) => String(code).trim().toLowerCase())
    .filter((code) => code.length > 0);
}

function variantsNamedBy(link: URL, variants: Json[]): Json[] {
  const linkKey = pageKey(link.toString(), link);
  const tokens = linkTokens(link);
  return variants.filter((variant) =>
    variantAddresses(variant).some((address) => pageKey(address, link) === linkKey) ||
    variantCodes(variant).some((code) => tokens.has(code))
  );
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function nameWithoutSize(variant: Json): string | null {
  const name = readText(variant.name);
  const size = readText(variant.size);
  if (!name || !size) return name;
  const suffix = new RegExp(`\\s*[-,|/:]\\s*(?:size\\s*)?${escapeRegExp(size)}$`, "i");
  return name.replace(suffix, "") || name;
}

function shared<T>(values: (T | null)[]): T | null {
  const present = values.filter((value): value is T => value !== null);
  if (present.length === 0) return null;
  return present.every((value) => value === present[0]) ? present[0] : null;
}

function agreeing(offers: Offer[]): Offer {
  const priced = offers.filter((offer) => offer.price !== null);
  if (priced.length === 0) return noOffer;
  const [first] = priced;
  const agree = priced.every((offer) =>
    offer.price === first.price && offer.currency === first.currency
  );
  return agree ? first : noOffer;
}

function isPriceRange(offer: Json): boolean {
  if (offer.lowPrice === undefined || offer.highPrice === undefined) return false;
  return readOffer({ price: offer.lowPrice }).price !== readOffer({ price: offer.highPrice }).price;
}

function groupOwnOffer(group: Json): Offer {
  const offers = listOf(group.offers).filter(isObject);
  return offers.some(isPriceRange) ? noOffer : agreeing(offers.map(readOffer));
}

function readGroup(group: Json, variants: Json[], link: URL): ProductFields {
  const named = variantsNamedBy(link, variants);
  const groupTitle = readText(group.name);
  const groupImage = readImage(group.image);
  const groupBrand = readText(group.brand);
  const variantsPriced = variants.some((variant) => readOffer(variant.offers).price !== null);
  const offerOf = (chosen: Json[]) =>
    variantsPriced
      ? agreeing(chosen.map((variant) => readOffer(variant.offers)))
      : groupOwnOffer(group);

  if (named.length === 0) {
    return { title: groupTitle, ...offerOf(variants), imageURL: groupImage, author: groupBrand };
  }

  const titles = named.length > 1 ? named.map(nameWithoutSize) : [readText(named[0].name)];
  return {
    title: shared(titles) ?? groupTitle,
    ...offerOf(named),
    imageURL: shared(named.map((variant) => readImage(variant.image))) ?? groupImage,
    author: shared(named.map((variant) => readText(variant.brand))) ?? groupBrand,
  };
}

function readProduct(node: Json): ProductFields {
  const offer = readOffer(node.offers);
  return {
    title: readText(node.name),
    ...offer,
    imageURL: readImage(node.image),
    author: readText(node.brand),
  };
}

export interface JsonLdReading {
  fields: ProductFields;
  isGroup: boolean;
}

function isGroupNode(node: Json): boolean {
  return typesOf(node).includes("ProductGroup") || listOf(node.hasVariant).some(isProduct);
}

function describesSameProduct(node: Json, main: Json): boolean {
  if (isGroupNode(node) || isGroupNode(main)) return false;
  if (typeof main["@id"] === "string" && node["@id"] === main["@id"]) return true;
  const name = readText(main.name)?.toLowerCase();
  return name !== undefined && readText(node.name)?.toLowerCase() === name;
}

function pageProductNodes(doc: HTMLDocument): Json[] {
  const nodes: Json[] = [];
  for (const script of doc.querySelectorAll('script[type="application/ld+json"]')) {
    const raw = script.textContent;
    if (!raw || raw.trim().length === 0) continue;
    try {
      nodes.push(...productNodesIn(JSON.parse(raw)));
    } catch {
      continue;
    }
  }
  return nodes;
}

export function extractJsonLd(doc: HTMLDocument, link: URL): JsonLdReading | null {
  const nodes = pageProductNodes(doc);
  if (nodes.length === 0) return null;
  const [main] = nodes;
  const node: Json = Object.assign(
    {},
    ...nodes.filter((other) => other === main || describesSameProduct(other, main)).reverse(),
  );
  const isGroup = isGroupNode(node);
  const fields = isGroup
    ? readGroup(node, listOf(node.hasVariant).filter(isProduct), link)
    : readProduct(node);
  return { fields, isGroup };
}
