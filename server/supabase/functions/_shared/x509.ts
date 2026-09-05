import { decodeBase64 } from "@std/encoding/base64";
import {
  bitString,
  children,
  content,
  integer,
  objectIdentifier,
  readNode,
  slice,
  time,
} from "./asn1.ts";

const curveByOid: Record<string, { name: "P-256" | "P-384"; size: number }> = {
  "1.2.840.10045.3.1.7": { name: "P-256", size: 32 },
  "1.3.132.0.34": { name: "P-384", size: 48 },
};

const hashBySignatureOid: Record<string, "SHA-256" | "SHA-384"> = {
  "1.2.840.10045.4.3.2": "SHA-256",
  "1.2.840.10045.4.3.3": "SHA-384",
};

export interface Certificate {
  der: Uint8Array;
  tbs: Uint8Array;
  issuer: Uint8Array;
  subject: Uint8Array;
  spki: Uint8Array;
  notBefore: Date;
  notAfter: Date;
  signatureHash: "SHA-256" | "SHA-384";
  signature: Uint8Array;
  curve: { name: "P-256" | "P-384"; size: number };
}

export function parseCertificate(der: Uint8Array): Certificate {
  const root = readNode(der, 0);
  const [tbsNode, algorithmNode, signatureNode] = children(der, root);

  const signatureOid = objectIdentifier(der, children(der, algorithmNode)[0]);
  const signatureHash = hashBySignatureOid[signatureOid];
  if (!signatureHash) throw new Error(`unsupported certificate signature ${signatureOid}`);

  const tbsChildren = children(der, tbsNode);
  const offset = tbsChildren[0].tag === 0xa0 ? 1 : 0;
  const issuerNode = tbsChildren[offset + 2];
  const validityNode = tbsChildren[offset + 3];
  const subjectNode = tbsChildren[offset + 4];
  const spkiNode = tbsChildren[offset + 5];

  const [notBeforeNode, notAfterNode] = children(der, validityNode);
  const spkiAlgorithm = children(der, children(der, spkiNode)[0]);
  if (objectIdentifier(der, spkiAlgorithm[0]) !== "1.2.840.10045.2.1") {
    throw new Error("certificate key is not ecdsa");
  }
  const curve = curveByOid[objectIdentifier(der, spkiAlgorithm[1])];
  if (!curve) throw new Error("unsupported certificate curve");

  return {
    der,
    tbs: slice(der, tbsNode),
    issuer: slice(der, issuerNode),
    subject: slice(der, subjectNode),
    spki: slice(der, spkiNode),
    notBefore: time(der, notBeforeNode),
    notAfter: time(der, notAfterNode),
    signatureHash,
    signature: bitString(der, signatureNode),
    curve,
  };
}

export function parsePem(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN CERTIFICATE-----/g, "")
    .replace(/-----END CERTIFICATE-----/g, "")
    .replace(/\s+/g, "");
  return decodeBase64(body);
}

export function sameBytes(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let i = 0; i < left.length; i++) diff |= left[i] ^ right[i];
  return diff === 0;
}

export function derSignatureToRaw(der: Uint8Array, size: number): Uint8Array {
  const sequence = readNode(der, 0);
  const [rNode, sNode] = children(der, sequence);
  const raw = new Uint8Array(size * 2);
  const r = integer(der, rNode);
  const s = integer(der, sNode);
  if (r.length > size || s.length > size) throw new Error("ecdsa signature is too long");
  raw.set(r, size - r.length);
  raw.set(s, size * 2 - s.length);
  return raw;
}

export async function publicKeyOf(certificate: Certificate): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "spki",
    certificate.spki as BufferSource,
    { name: "ECDSA", namedCurve: certificate.curve.name },
    false,
    ["verify"],
  );
}

export async function verifySignedBy(
  certificate: Certificate,
  issuer: Certificate,
): Promise<boolean> {
  const key = await publicKeyOf(issuer);
  const raw = derSignatureToRaw(certificate.signature, issuer.curve.size);
  return await crypto.subtle.verify(
    { name: "ECDSA", hash: certificate.signatureHash },
    key,
    raw as BufferSource,
    certificate.tbs as BufferSource,
  );
}

export function extensionValue(der: Uint8Array, oid: string): Uint8Array | null {
  const root = readNode(der, 0);
  const tbsNode = children(der, root)[0];
  const tbsChildren = children(der, tbsNode);
  const extensionsNode = tbsChildren.find((node) => node.tag === 0xa3);
  if (!extensionsNode) return null;
  const sequence = children(der, extensionsNode)[0];
  for (const extension of children(der, sequence)) {
    const parts = children(der, extension);
    if (objectIdentifier(der, parts[0]) !== oid) continue;
    const valueNode = parts[parts.length - 1];
    return content(der, valueNode);
  }
  return null;
}
