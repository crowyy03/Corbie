import type { HTMLDocument } from "../../html.ts";
import { acceptAmount, normalizeCurrencyCode } from "../price.ts";
import { emptyFields, type ProductFields } from "../types.ts";
import type { Adapter } from "./adapter.ts";

type Json = Record<string, unknown>;

const stateMarker = "window.__PRELOADED_STATE__";
const productPath = /\/products\/([^/]+)\/([^/]+)/;

function isObject(value: unknown): value is Json {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function child(value: unknown, key: string): unknown {
  return isObject(value) ? value[key] : undefined;
}

function preloadedState(doc: HTMLDocument): unknown {
  for (const script of doc.querySelectorAll("script")) {
    const text = script.textContent.trim();
    if (!text.startsWith(stateMarker)) continue;
    const assigned = text.slice(text.indexOf("=") + 1).trim().replace(/;$/, "");
    try {
      return JSON.parse(assigned);
    } catch {
      return null;
    }
  }
  return null;
}

export const uniqloAdapter: Adapter = {
  source: "uniqlo",
  matches: (host) => host === "uniqlo.com" || host.endsWith(".uniqlo.com"),
  ownsPrice: true,
  extract(doc: HTMLDocument, pageUrl: URL): ProductFields {
    const path = pageUrl.pathname.match(productPath);
    if (!path) return { ...emptyFields };
    const entry = child(child(preloadedState(doc), "entity"), "pdpEntity");
    const prices = child(child(child(entry, `${path[1]}-${path[2]}`), "product"), "prices");
    const promo = child(prices, "promo");
    const current = isObject(promo) ? promo : child(prices, "base");
    const value = child(current, "value");
    const code = child(child(current, "currency"), "code");
    const price = typeof value === "number" ? acceptAmount(value) : null;
    return {
      ...emptyFields,
      price,
      currency: price === null
        ? null
        : normalizeCurrencyCode(typeof code === "string" ? code : null),
    };
  },
};
