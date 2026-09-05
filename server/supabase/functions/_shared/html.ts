import { DOMParser, type Element, type HTMLDocument } from "@b-fuze/deno-dom";

export type { Element, HTMLDocument };

export function parseHtml(html: string): HTMLDocument {
  const doc = new DOMParser().parseFromString(html, "text/html");
  if (!doc) throw new Error("html parse failed");
  return doc;
}

export function attr(doc: HTMLDocument, selector: string, name: string): string | null {
  const value = doc.querySelector(selector)?.getAttribute(name);
  return value && value.trim().length > 0 ? value.trim() : null;
}

export function text(doc: HTMLDocument, selector: string): string | null {
  const value = doc.querySelector(selector)?.textContent;
  return value && value.trim().length > 0 ? collapse(value) : null;
}

export function textOfAny(doc: HTMLDocument, selectors: string[]): string | null {
  for (const selector of selectors) {
    const value = text(doc, selector);
    if (value) return value;
  }
  return null;
}

export function attrOfAny(
  doc: HTMLDocument,
  selectors: string[],
  name: string,
): string | null {
  for (const selector of selectors) {
    const value = attr(doc, selector, name);
    if (value) return value;
  }
  return null;
}

export function collapse(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}
