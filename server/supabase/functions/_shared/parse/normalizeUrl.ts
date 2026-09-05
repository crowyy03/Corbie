const trackingParams = new Set([
  "fbclid",
  "gclid",
  "gclsrc",
  "dclid",
  "msclkid",
  "mc_cid",
  "mc_eid",
  "igshid",
  "igsh",
  "ref",
  "ref_",
  "ref_src",
  "referrer",
  "spm",
  "yclid",
  "_ga",
  "_gl",
  "vero_id",
  "twclid",
  "ttclid",
]);

const amazonParams = new Set([
  "tag",
  "ascsubtag",
  "linkcode",
  "linkid",
  "creative",
  "creativeasin",
  "camp",
  "smid",
  "psc",
  "th",
  "qid",
  "sr",
  "sprefix",
  "crid",
  "keywords",
  "dib",
  "dib_tag",
  "content-id",
  "_encoding",
  "pd_rd_i",
  "pd_rd_r",
  "pd_rd_w",
  "pd_rd_wg",
  "pf_rd_i",
  "pf_rd_m",
  "pf_rd_p",
  "pf_rd_r",
  "pf_rd_s",
  "pf_rd_t",
]);

const amazonShortHosts = new Set(["a.co", "amzn.to", "amzn.eu", "amzn.asia"]);

export function hostOf(url: URL): string {
  return url.hostname.toLowerCase().replace(/^www\./, "");
}

export function isAmazonHost(host: string): boolean {
  return host === "amazon.com" || host.startsWith("amazon.") || host.endsWith(".amazon.com");
}

export function isAmazonShortLink(raw: string): boolean {
  try {
    return amazonShortHosts.has(hostOf(new URL(raw)));
  } catch {
    return false;
  }
}

export function normalizeUrl(raw: string): string {
  const url = new URL(raw.trim());
  if (url.protocol !== "https:" && url.protocol !== "http:") {
    throw new TypeError("unsupported scheme");
  }
  url.protocol = "https:";
  url.hostname = url.hostname.toLowerCase();
  url.hash = "";
  url.username = "";
  url.password = "";
  if (url.port === "443" || url.port === "80") url.port = "";

  const host = hostOf(url);
  const amazon = isAmazonHost(host);

  for (const key of [...url.searchParams.keys()]) {
    const lower = key.toLowerCase();
    if (lower.startsWith("utm_") || trackingParams.has(lower)) url.searchParams.delete(key);
    else if (amazon && amazonParams.has(lower)) url.searchParams.delete(key);
  }
  url.searchParams.sort();

  if (amazon) {
    const asin = url.pathname.match(
      /\/(?:dp|gp\/product|gp\/aw\/d|product)\/([A-Z0-9]{10})(?:[/?]|$)/i,
    );
    if (asin) {
      url.pathname = `/dp/${asin[1].toUpperCase()}`;
      url.search = "";
    }
  }

  if (url.pathname.length > 1 && url.pathname.endsWith("/")) {
    url.pathname = url.pathname.replace(/\/+$/, "");
  }

  return url.toString();
}

export async function resolveShortLink(
  raw: string,
  fetchImpl: typeof fetch = fetch,
): Promise<string> {
  if (!isAmazonShortLink(raw)) return raw;
  let current = raw;
  for (let hop = 0; hop < 5; hop++) {
    let response: Response;
    try {
      response = await fetchImpl(current, {
        method: "GET",
        redirect: "manual",
        signal: AbortSignal.timeout(5000),
        headers: { "user-agent": browserUserAgent },
      });
    } catch {
      return current;
    }
    await response.body?.cancel();
    const location = response.headers.get("location");
    if (!location || response.status < 300 || response.status >= 400) return current;
    current = new URL(location, current).toString();
  }
  return current;
}

export const browserUserAgent =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15";
