import { assert, assertEquals, assertRejects } from "@std/assert";
import { encodeBase64 } from "@std/encoding/base64";
import { encodeBase64Url } from "@std/encoding/base64url";
import {
  appleRootCaG3Pem,
  appleRootCaG3Sha256,
} from "../supabase/functions/_shared/appleRootCA.ts";
import { decodeJwsPayload, verifyAppleJws } from "../supabase/functions/_shared/appleJws.ts";
import {
  derSignatureToRaw,
  parseCertificate,
  parsePem,
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

Deno.test("a chain anchored correctly still needs a valid payload signature", async () => {
  const jws = await signWithFreshKey([encodeBase64(root.der), encodeBase64(root.der)]);
  await assertRejects(() => verifyAppleJws(jws), ApiError, "signature is invalid");
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
