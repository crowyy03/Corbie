import { decodeBase64 } from "@std/encoding/base64";
import { encodeBase64Url } from "@std/encoding/base64url";
import { jwtSegment } from "./jwt.ts";
import { ApiError } from "./respond.ts";

function pkcs8FromPem(pem: string): Uint8Array {
  const body = pem.replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  if (body.length === 0) throw new Error("empty key");
  return decodeBase64(body);
}

export async function importEs256PrivateKey(pem: string, secretName: string): Promise<CryptoKey> {
  try {
    return await crypto.subtle.importKey(
      "pkcs8",
      pkcs8FromPem(pem) as BufferSource,
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign"],
    );
  } catch {
    throw new ApiError("internal", `${secretName} could not be read`);
  }
}

export async function signEs256Jwt(
  key: CryptoKey,
  header: Record<string, unknown>,
  claims: Record<string, unknown>,
): Promise<string> {
  const signingInput = `${jwtSegment(header)}.${jwtSegment(claims)}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${encodeBase64Url(new Uint8Array(signature))}`;
}
