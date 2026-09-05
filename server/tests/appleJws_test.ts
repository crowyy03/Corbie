import { assert, assertEquals, assertRejects } from "@std/assert";
import { encodeBase64 } from "@std/encoding/base64";
import { encodeBase64Url } from "@std/encoding/base64url";
import {
  appleRootCaG3Pem,
  appleRootCaG3Sha256,
} from "../supabase/functions/_shared/appleRootCA.ts";
import {
  appStoreSigningOid,
  decodeJwsPayload,
  verifyAppleJws,
} from "../supabase/functions/_shared/appleJws.ts";
import {
  allowsCertificateSigning,
  derSignatureToRaw,
  hasExtension,
  isCertificateAuthority,
  parseCertificate,
  parsePem,
  pathLengthConstraint,
  sameBytes,
  verifySignedBy,
} from "../supabase/functions/_shared/x509.ts";
import { ApiError } from "../supabase/functions/_shared/respond.ts";

const root = parseCertificate(parsePem(appleRootCaG3Pem));

function hex(bytes: Uint8Array): string {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.test("the embedded pem is the Apple Root CA G3", async () => {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", root.der as BufferSource));
  assertEquals(hex(digest), appleRootCaG3Sha256);
});

Deno.test("the root parses as a self signed P-384 certificate", () => {
  assertEquals(root.curve.name, "P-384");
  assertEquals(root.signatureHash, "SHA-384");
  assert(sameBytes(root.issuer, root.subject));
  assertEquals(root.notBefore.toISOString(), "2014-04-30T18:19:06.000Z");
  assertEquals(root.notAfter.toISOString(), "2039-04-30T18:19:06.000Z");
});

Deno.test("the root certificate verifies against its own key", async () => {
  assertEquals(await verifySignedBy(root, root), true);
});

Deno.test("a tampered root does not verify", async () => {
  const tampered = parseCertificate(parsePem(appleRootCaG3Pem));
  tampered.tbs = tampered.tbs.slice();
  tampered.tbs[tampered.tbs.length - 1] ^= 0xff;
  assertEquals(await verifySignedBy(tampered, root), false);
});

Deno.test("der ecdsa signatures are left padded to the curve size", () => {
  const der = new Uint8Array([0x30, 0x08, 0x02, 0x01, 0x07, 0x02, 0x03, 0x00, 0xff, 0x01]);
  assertEquals(hex(derSignatureToRaw(der, 4)), "000000070000ff01");
});

Deno.test("a chain that ends in a foreign root is rejected", async () => {
  const foreign = root.der.slice();
  foreign[foreign.length - 1] ^= 0xff;
  const jws = await signWithFreshKey([encodeBase64(root.der), encodeBase64(foreign)]);
  await assertRejects(() => verifyAppleJws(jws), ApiError, "not anchored to the Apple root");
});

Deno.test("the apple root may sign certificates and is not an app store signing key", () => {
  assertEquals(isCertificateAuthority(root.der), true);
  assertEquals(allowsCertificateSigning(root.der), true);
  assertEquals(pathLengthConstraint(root.der), null);
  assertEquals(hasExtension(root.der, appStoreSigningOid), false);
});

Deno.test("a chain whose leaf is any other apple certificate is rejected", async () => {
  const jws = await signWithFreshKey([encodeBase64(root.der), encodeBase64(root.der)]);
  await assertRejects(() => verifyAppleJws(jws), ApiError, "App Store signing key");
});

Deno.test("an app store leaf is carried on to the chain linkage check", async () => {
  const leaf = testCertificate({ appStoreLeaf: true });
  const jws = await signWithFreshKey([encodeBase64(leaf), encodeBase64(root.der)]);
  await assertRejects(() => verifyAppleJws(jws), ApiError, "chain is broken");
});

Deno.test("an intermediate without ca basic constraints is rejected", async () => {
  const jws = await signWithFreshKey([
    encodeBase64(testCertificate({ appStoreLeaf: true })),
    encodeBase64(testCertificate({ keyCertSign: true })),
    encodeBase64(root.der),
  ]);
  await assertRejects(() => verifyAppleJws(jws), ApiError, "may not sign certificates");
});

Deno.test("an intermediate without the key cert sign bit is rejected", async () => {
  const jws = await signWithFreshKey([
    encodeBase64(testCertificate({ appStoreLeaf: true })),
    encodeBase64(testCertificate({ ca: true })),
    encodeBase64(root.der),
  ]);
  await assertRejects(() => verifyAppleJws(jws), ApiError, "may not sign certificates");
});

Deno.test("a chain deeper than the path length constraint is rejected", async () => {
  const jws = await signWithFreshKey([
    encodeBase64(testCertificate({ appStoreLeaf: true })),
    encodeBase64(testCertificate({ ca: true, keyCertSign: true })),
    encodeBase64(testCertificate({ ca: true, keyCertSign: true, pathLength: 0 })),
    encodeBase64(root.der),
  ]);
  await assertRejects(() => verifyAppleJws(jws), ApiError, "longer than its constraint");
});

Deno.test("a certificate outside its validity window is rejected", async () => {
  const jws = await signWithFreshKey([encodeBase64(root.der), encodeBase64(root.der)]);
  await assertRejects(
    () => verifyAppleJws(jws, new Date("2013-01-01T00:00:00Z")),
    ApiError,
    "validity window",
  );
});

Deno.test("a chain with no certificates at all is rejected", async () => {
  const header = { alg: "ES256" };
  const jws = `${encodeSegment(header)}.${encodeSegment({})}.AAAA`;
  await assertRejects(() => verifyAppleJws(jws), ApiError, "certificate chain");
});

Deno.test("a payload signed with the wrong algorithm is rejected", async () => {
  const header = { alg: "RS256", x5c: [encodeBase64(root.der)] };
  const jws = `${encodeSegment(header)}.${encodeSegment({})}.AAAA`;
  await assertRejects(() => verifyAppleJws(jws), ApiError, "algorithm");
});

Deno.test("payloads can be read without verifying, for logging only", () => {
  const jws = `${encodeSegment({ alg: "ES256" })}.${
    encodeSegment({ notificationType: "REFUND" })
  }.AAAA`;
  assertEquals(decodeJwsPayload<{ notificationType: string }>(jws).notificationType, "REFUND");
});

function concatBytes(parts: Uint8Array[]): Uint8Array {
  const result = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    result.set(part, offset);
    offset += part.length;
  }
  return result;
}

function encodedLength(length: number): Uint8Array {
  if (length < 0x80) return Uint8Array.of(length);
  const bytes: number[] = [];
  let rest = length;
  while (rest > 0) {
    bytes.unshift(rest & 0xff);
    rest = rest >> 8;
  }
  return Uint8Array.from([0x80 | bytes.length, ...bytes]);
}

function tlv(tag: number, ...parts: Uint8Array[]): Uint8Array {
  const body = concatBytes(parts);
  return concatBytes([Uint8Array.of(tag), encodedLength(body.length), body]);
}

function oid(value: string): Uint8Array {
  const parts = value.split(".").map(Number);
  const bytes: number[] = [parts[0] * 40 + parts[1]];
  for (const part of parts.slice(2)) {
    const chunk = [part & 0x7f];
    let rest = Math.floor(part / 128);
    while (rest > 0) {
      chunk.unshift((rest & 0x7f) | 0x80);
      rest = Math.floor(rest / 128);
    }
    bytes.push(...chunk);
  }
  return tlv(0x06, Uint8Array.from(bytes));
}

function text(tag: number, value: string): Uint8Array {
  return tlv(tag, new TextEncoder().encode(value));
}

function commonName(value: string): Uint8Array {
  return tlv(0x30, tlv(0x31, tlv(0x30, oid("2.5.4.3"), text(0x0c, value))));
}

function extension(id: string, value: Uint8Array): Uint8Array {
  return tlv(0x30, oid(id), tlv(0x04, value));
}

interface TestCertificateOptions {
  ca?: boolean;
  keyCertSign?: boolean;
  pathLength?: number;
  appStoreLeaf?: boolean;
}

function testCertificate(options: TestCertificateOptions): Uint8Array {
  const constraints = options.ca
    ? tlv(
      0x30,
      tlv(0x01, Uint8Array.of(0xff)),
      ...(options.pathLength === undefined ? [] : [tlv(0x02, Uint8Array.of(options.pathLength))]),
    )
    : tlv(0x30, tlv(0x01, Uint8Array.of(0x00)));
  const usage = options.keyCertSign
    ? tlv(0x03, Uint8Array.of(0x02, 0x04))
    : tlv(0x03, Uint8Array.of(0x07, 0x80));
  const extensions = [
    extension("2.5.29.19", constraints),
    extension("2.5.29.15", usage),
    ...(options.appStoreLeaf ? [extension(appStoreSigningOid, Uint8Array.of(0x05, 0x00))] : []),
  ];
  const algorithm = tlv(0x30, oid("1.2.840.10045.4.3.2"));
  const tbs = tlv(
    0x30,
    tlv(0xa0, tlv(0x02, Uint8Array.of(0x02))),
    tlv(0x02, Uint8Array.of(0x01)),
    algorithm,
    commonName("Corbie Test Issuer"),
    tlv(0x30, text(0x18, "20200101000000Z"), text(0x18, "20400101000000Z")),
    commonName("Corbie Test Subject"),
    tlv(
      0x30,
      tlv(0x30, oid("1.2.840.10045.2.1"), oid("1.2.840.10045.3.1.7")),
      tlv(0x03, Uint8Array.of(0x00, 0x04), new Uint8Array(64)),
    ),
    tlv(0xa3, tlv(0x30, ...extensions)),
  );
  const signature = tlv(0x30, tlv(0x02, Uint8Array.of(0x01)), tlv(0x02, Uint8Array.of(0x01)));
  return tlv(0x30, tbs, algorithm, tlv(0x03, Uint8Array.of(0x00), signature));
}

function encodeSegment(value: unknown): string {
  return encodeBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

async function signWithFreshKey(x5c: string[]): Promise<string> {
  const pair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  ) as CryptoKeyPair;
  const signingInput = `${encodeSegment({ alg: "ES256", x5c })}.${
    encodeSegment({ notificationType: "SUBSCRIBED" })
  }`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    pair.privateKey,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${encodeBase64Url(new Uint8Array(signature))}`;
}
