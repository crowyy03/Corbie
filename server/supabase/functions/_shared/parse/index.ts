import { parseHtml } from "../html.ts";
import { adapterForHost } from "./adapters/index.ts";
import { safeFetch } from "./guard.ts";
import { extractJsonLd } from "./jsonld.ts";
import { browserHeaders } from "./browserHeaders.ts";
import { extractMicrodata } from "./microdata.ts";
import { hostOf, normalizeUrl, resolveShortLink } from "./normalizeUrl.ts";
import { fetchOEmbed } from "./oembed.ts";
import { declaresProduct, extractOpenGraph, readSiteName } from "./og.ts";
import { extractTitleTag, stripSiteName } from "./title.ts";
import {
  emptyFields,
  type MergedFields,
  mergeFields,
  type ParseResult,
  type ParseSource,
  type ProductFields,
  type SourcedFields,
} from "./types.ts";
import { type ParseTrace, type Upstream, upstreamFailure } from "./upstream.ts";

export * from "./types.ts";
export * from "./upstream.ts";

const upstreamTimeoutMs = 8000;
const maxHtmlBytes = 3 * 1024 * 1024;
const maxTitleLength = 300;

export interface PageReading extends MergedFields {
  isProductPage: boolean;
}

export interface ParseOutcome {
  result: ParseResult;
  trace: ParseTrace;
}

export function sourceForHost(host: string): ParseSource {
  if (host === "instagram.com" || host.endsWith(".instagram.com")) return "instagram";
  if (host === "tiktok.com" || host.endsWith(".tiktok.com")) return "tiktok";
  return adapterForHost(host)?.source ?? "generic";
}

function withoutPrice(reading: SourcedFields): SourcedFields {
  return { ...reading, fields: { ...reading.fields, price: null, currency: null } };
}

export function extractFields(html: string, link: URL): PageReading {
  const doc = parseHtml(html);
  const host = hostOf(link);
  const adapter = adapterForHost(host);
  const jsonld = extractJsonLd(doc, link);
  const pageTags: SourcedFields[] = jsonld?.isGroup ? [] : [
    { source: "og", fields: extractOpenGraph(doc) },
    { source: "microdata", fields: extractMicrodata(doc) },
    { source: "title-tag", fields: extractTitleTag(doc) },
  ];
  const genericReadings: SourcedFields[] = [
    ...(jsonld ? [{ source: "jsonld" as const, fields: jsonld.fields }] : []),
    ...pageTags,
  ];
  const readings: SourcedFields[] = [
    ...(adapter ? [{ source: "adapter" as const, fields: adapter.extract(doc, link) }] : []),
    ...(adapter?.ownsPrice ? genericReadings.map(withoutPrice) : genericReadings),
  ];
  const merged = mergeFields(readings);
  const { title, price, imageURL } = merged.fields;
  return {
    ...merged,
    fields: {
      ...merged.fields,
      title: title ? stripSiteName(title, readSiteName(doc), host) : null,
    },
    isProductPage: jsonld !== null || declaresProduct(doc) || price !== null || imageURL !== null,
  };
}

export function landedOffProduct(requested: URL, landed: URL): boolean {
  const isProductPath = adapterForHost(hostOf(requested))?.isProductPath;
  if (!isProductPath) return false;
  return isProductPath(requested.pathname) && !isProductPath(landed.pathname);
}

function landedUrl(response: Response, requested: string): URL {
  try {
    return new URL(response.url.length > 0 ? response.url : requested);
  } catch {
    return new URL(requested);
  }
}

function absolute(candidate: string | null, base: string): string | null {
  if (!candidate) return null;
  try {
    const url = new URL(candidate, base);
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;
    return url.toString();
  } catch {
    return null;
  }
}

function tidy(fields: ProductFields, canonicalURL: string): ProductFields {
  const title = fields.title ? fields.title.slice(0, maxTitleLength).trim() : null;
  return {
    title: title && title.length > 0 ? title : null,
    price: fields.price,
    currency: fields.price === null ? null : fields.currency,
    imageURL: absolute(fields.imageURL, canonicalURL),
    author: fields.author ? fields.author.slice(0, maxTitleLength).trim() : null,
  };
}

async function readCapped(body: ReadableStream<Uint8Array>): Promise<Uint8Array> {
  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (total < maxHtmlBytes) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    total += value.length;
  }
  await reader.cancel().catch(() => {});

  const capped = new Uint8Array(Math.min(total, maxHtmlBytes));
  let offset = 0;
  for (const chunk of chunks) {
    if (offset >= capped.length) break;
    const room = capped.length - offset;
    capped.set(chunk.length > room ? chunk.subarray(0, room) : chunk, offset);
    offset += Math.min(chunk.length, room);
  }
  return capped;
}

async function readHtml(response: Response): Promise<string | null> {
  const type = response.headers.get("content-type") ?? "";
  if (type.length > 0 && !type.toLowerCase().includes("html")) {
    await response.body?.cancel();
    return null;
  }
  if (!response.body) return null;
  const capped = await readCapped(response.body);
  return new TextDecoder("utf-8", { fatal: false }).decode(capped);
}

export async function canonicalizeUrl(
  rawUrl: string,
  fetchImpl: typeof fetch = safeFetch,
): Promise<string> {
  return normalizeUrl(await resolveShortLink(rawUrl.trim(), fetchImpl));
}

export async function parseLink(
  rawUrl: string,
  fetchImpl: typeof fetch = safeFetch,
): Promise<ParseOutcome> {
  const canonicalURL = await canonicalizeUrl(rawUrl, fetchImpl);
  const link = new URL(canonicalURL);
  const source = sourceForHost(hostOf(link));
  const bare: ParseResult = { canonicalURL, source, ...emptyFields };
  const unread = (upstream: Upstream): ParseOutcome => ({
    result: bare,
    trace: { upstream, page: "unread", titleFrom: "none", priceFrom: "none" },
  });

  if (source === "instagram" || source === "tiktok") {
    const { fields, upstream } = await fetchOEmbed(source, canonicalURL, fetchImpl);
    return {
      result: {
        canonicalURL,
        source,
        ...tidy(fields, canonicalURL),
        title: null,
        price: null,
        currency: null,
      },
      trace: { upstream, page: "unread", titleFrom: "none", priceFrom: "none" },
    };
  }

  let response: Response;
  try {
    response = await fetchImpl(canonicalURL, {
      redirect: "follow",
      signal: AbortSignal.timeout(upstreamTimeoutMs),
      headers: browserHeaders(canonicalURL),
    });
  } catch (cause) {
    return unread(upstreamFailure(cause));
  }

  if (!response.ok) {
    await response.body?.cancel();
    return unread(response.status);
  }
  if (landedOffProduct(link, landedUrl(response, canonicalURL))) {
    await response.body?.cancel();
    return unread("redirect");
  }

  let html: string | null;
  try {
    html = await readHtml(response);
  } catch (cause) {
    return unread(upstreamFailure(cause));
  }
  if (html === null) return unread("non-html");

  let reading: PageReading;
  try {
    reading = extractFields(html, link);
  } catch {
    return unread(response.status);
  }
  if (!reading.isProductPage) {
    return {
      result: bare,
      trace: {
        upstream: response.status,
        page: "not-product",
        titleFrom: "none",
        priceFrom: "none",
      },
    };
  }

  const fields = tidy(reading.fields, canonicalURL);
  return {
    result: { canonicalURL, source, ...fields },
    trace: {
      upstream: response.status,
      page: "product",
      titleFrom: fields.title === null ? "none" : reading.titleFrom,
      priceFrom: fields.price === null ? "none" : reading.priceFrom,
    },
  };
}
