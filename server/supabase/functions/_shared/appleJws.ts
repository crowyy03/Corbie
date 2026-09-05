import { decodeBase64 } from "@std/encoding/base64";
import { decodeBase64Url } from "@std/encoding/base64url";
import { appleRootCaG3Pem } from "./appleRootCA.ts";
import { ApiError } from "./respond.ts";
import { parseCertificate, parsePem, publicKeyOf, sameBytes, verifySignedBy } from "./x509.ts";
import type { Certificate } from "./x509.ts";

let trustedRoot: Certificate | null = null;

function rootCertificate(): Certificate {
  if (!trustedRoot) trustedRoot = parseCertificate(parsePem(appleRootCaG3Pem));
  return trustedRoot;
}

function decodeJson(segment: string): Record<string, unknown> {
  return JSON.parse(new TextDecoder().decode(decodeBase64Url(segment)));
}

export function decodeJwsPayload<T>(jws: string): T {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new ApiError("invalid_request", "Signed payload is malformed");
  try {
    return decodeJson(parts[1]) as T;
  } catch {
    throw new ApiError("invalid_request", "Signed payload is malformed");
  }
}

async function verifyChain(x5c: string[], at: Date): Promise<Certificate> {
  if (x5c.length < 2) throw new ApiError("unauthorized", "Signed payload has no certificate chain");

  const chain = x5c.map((entry) => parseCertificate(decodeBase64(entry)));
  const root = rootCertificate();

  const last = chain[chain.length - 1];
  if (!sameBytes(last.der, root.der)) {
    throw new ApiError("unauthorized", "Signed payload is not anchored to the Apple root");
  }

  for (const certificate of chain) {
    if (at < certificate.notBefore || at > certificate.notAfter) {
      throw new ApiError(
        "unauthorized",
        "Signed payload certificate is out of its validity window",
      );
    }
  }

  for (let i = 0; i < chain.length - 1; i++) {
    const child = chain[i];
    const parent = chain[i + 1];
    if (!sameBytes(child.issuer, parent.subject)) {
      throw new ApiError("unauthorized", "Signed payload certificate chain is broken");
    }
    if (!await verifySignedBy(child, parent)) {
      throw new ApiError("unauthorized", "Signed payload certificate signature is invalid");
    }
  }

  return chain[0];
}

export async function verifyAppleJws<T>(jws: string, at: Date = new Date()): Promise<T> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new ApiError("invalid_request", "Signed payload is malformed");

  let header: Record<string, unknown>;
  try {
    header = decodeJson(parts[0]);
  } catch {
    throw new ApiError("invalid_request", "Signed payload is malformed");
  }
  if (header.alg !== "ES256") throw new ApiError("unauthorized", "Unsupported payload algorithm");
  const x5c = header.x5c;
  if (!Array.isArray(x5c) || x5c.some((entry) => typeof entry !== "string")) {
    throw new ApiError("unauthorized", "Signed payload has no certificate chain");
  }

  const leaf = await verifyChain(x5c as string[], at);
  const key = await publicKeyOf(leaf);
  const signature = decodeBase64Url(parts[2]);
  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    signature as BufferSource,
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!valid) throw new ApiError("unauthorized", "Signed payload signature is invalid");

  try {
    return decodeJson(parts[1]) as T;
  } catch {
    throw new ApiError("invalid_request", "Signed payload is malformed");
  }
}
