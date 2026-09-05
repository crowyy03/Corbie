const maxRedirects = 5;
const redirectStatuses = new Set([301, 302, 303, 307, 308]);

export type AddressResolver = (hostname: string) => Promise<string[] | null>;

function parseIpv4(value: string): number[] | null {
  const parts = value.split(".");
  if (parts.length !== 4) return null;
  const bytes: number[] = [];
  for (const part of parts) {
    if (!/^\d{1,3}$/.test(part)) return null;
    const byte = Number(part);
    if (byte > 255) return null;
    bytes.push(byte);
  }
  return bytes;
}

function parseIpv6(value: string): number[] | null {
  const withoutZone = value.split("%")[0];
  if (!withoutZone.includes(":")) return null;
  const halves = withoutZone.split("::");
  if (halves.length > 2) return null;

  const groups = (part: string): number[] | null => {
    if (part.length === 0) return [];
    const bytes: number[] = [];
    const pieces = part.split(":");
    for (let i = 0; i < pieces.length; i++) {
      const piece = pieces[i];
      if (piece.includes(".")) {
        if (i !== pieces.length - 1) return null;
        const ipv4 = parseIpv4(piece);
        if (!ipv4) return null;
        bytes.push(...ipv4);
        continue;
      }
      if (!/^[0-9a-f]{1,4}$/i.test(piece)) return null;
      const group = Number.parseInt(piece, 16);
      bytes.push(group >> 8, group & 0xff);
    }
    return bytes;
  };

  const head = groups(halves[0]);
  const tail = halves.length === 2 ? groups(halves[1]) : [];
  if (!head || !tail) return null;
  if (halves.length === 1) return head.length === 16 ? head : null;
  const gap = 16 - head.length - tail.length;
  if (gap <= 0) return null;
  return [...head, ...new Array(gap).fill(0), ...tail];
}

function isBlockedIpv4(bytes: number[]): boolean {
  const [a, b] = bytes;
  if (a === 0 || a === 10 || a === 127 || a >= 224) return true;
  if (a === 169 && b === 254) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 192 && (b === 0 || b === 168)) return true;
  if (a === 100 && b >= 64 && b <= 127) return true;
  if (a === 198 && (b === 18 || b === 19)) return true;
  return false;
}

function isBlockedIpv6(bytes: number[]): boolean {
  const leading = bytes.slice(0, 10).every((byte) => byte === 0);
  if (leading && bytes[10] === 0xff && bytes[11] === 0xff) return isBlockedIpv4(bytes.slice(12));
  if (leading && bytes[10] === 0 && bytes[11] === 0) return true;
  if (bytes[0] === 0x00 && bytes[1] === 0x64 && bytes[2] === 0xff && bytes[3] === 0x9b) {
    return isBlockedIpv4(bytes.slice(12));
  }
  if ((bytes[0] & 0xfe) === 0xfc) return true;
  if (bytes[0] === 0xfe && (bytes[1] & 0xc0) === 0x80) return true;
  if (bytes[0] === 0xff) return true;
  return false;
}

export function isPrivateAddress(value: string): boolean {
  const ipv4 = parseIpv4(value);
  if (ipv4) return isBlockedIpv4(ipv4);
  const ipv6 = parseIpv6(value);
  if (ipv6) return isBlockedIpv6(ipv6);
  return true;
}

export function isAddressLiteral(host: string): boolean {
  return parseIpv4(host) !== null || parseIpv6(host) !== null;
}

export function isPrivateHostname(host: string): boolean {
  if (host === "localhost" || host.endsWith(".localhost")) return true;
  if (host.endsWith(".local") || host.endsWith(".internal")) return true;
  return host.endsWith(".home.arpa") || host.endsWith(".onion");
}

async function resolveAddresses(hostname: string): Promise<string[] | null> {
  if (typeof Deno.resolveDns !== "function") return null;
  const found: string[] = [];
  for (const kind of ["A", "AAAA"] as const) {
    try {
      found.push(...await Deno.resolveDns(hostname, kind));
    } catch (cause) {
      if (cause instanceof Deno.errors.NotFound) continue;
      return null;
    }
  }
  return found;
}

export async function assertFetchable(
  url: URL,
  resolve: AddressResolver = resolveAddresses,
): Promise<void> {
  if (url.protocol !== "https:" && url.protocol !== "http:") {
    throw new TypeError("url must be http or https");
  }
  if (url.port.length > 0 && url.port !== "443") throw new TypeError("url port is not allowed");

  const host = url.hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (host.length === 0) throw new TypeError("url has no host");
  if (isAddressLiteral(host)) throw new TypeError("url must name a host, not an address");
  if (isPrivateHostname(host)) throw new TypeError("url points inside a private network");

  const addresses = await resolve(host);
  if (addresses === null) return;
  if (addresses.length === 0) throw new TypeError("url host does not resolve");
  for (const address of addresses) {
    if (isPrivateAddress(address)) throw new TypeError("url points inside a private network");
  }
}

export function safeFetchWith(
  inner: typeof fetch,
  resolve: AddressResolver = resolveAddresses,
): typeof fetch {
  return async (input, init = {}) => {
    const follow = init.redirect !== "manual";
    let current = new URL(input instanceof Request ? input.url : input.toString());
    for (let hop = 0; hop <= maxRedirects; hop++) {
      await assertFetchable(current, resolve);
      const response = await inner(current, { ...init, redirect: "manual" });
      if (!follow || !redirectStatuses.has(response.status)) return response;
      const location = response.headers.get("location");
      if (location === null) return response;
      await response.body?.cancel();
      current = new URL(location, current);
    }
    throw new TypeError("url redirects too many times");
  };
}

export const safeFetch: typeof fetch = safeFetchWith((input, init) => fetch(input, init));
