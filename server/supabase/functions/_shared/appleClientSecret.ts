import { decodeBase64 } from "@std/encoding/base64";
import { encodeBase64Url } from "@std/encoding/base64url";
import { appleClientId } from "./appleAuth.ts";
import { ApiError, requiredEnv } from "./respond.ts";

const audience = "https://appleid.apple.com";
const lifetimeSeconds = 15 * 60;

function pkcs8FromPem(pem: string): Uint8Array {
  const normalized = pem.replace(/\\n/g, "\n");
  const body = normalized
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  if (body.length === 0) throw new ApiError("internal", "APPLE_PRIVATE_KEY is not a PKCS8 PEM");
  return decodeBase64(body);
}

function segment(value: unknown): string {
  return encodeBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

export async function buildAppleClientSecret(now: Date = new Date()): Promise<string> {
  const teamId = requiredEnv("APPLE_TEAM_ID");
  const keyId = requiredEnv("APPLE_KEY_ID");
  const privateKeyPem = requiredEnv("APPLE_PRIVATE_KEY");

  let key: CryptoKey;
  try {
    key = await crypto.subtle.importKey(
      "pkcs8",
      pkcs8FromPem(privateKeyPem) as BufferSource,
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign"],
    );
  } catch {
    throw new ApiError("internal", "APPLE_PRIVATE_KEY could not be read");
  }

  const issuedAt = Math.floor(now.getTime() / 1000);
  const header = segment({ alg: "ES256", kid: keyId, typ: "JWT" });
  const claims = segment({
    iss: teamId,
    iat: issuedAt,
    exp: issuedAt + lifetimeSeconds,
    aud: audience,
    sub: appleClientId(),
  });

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );

  return `${header}.${claims}.${encodeBase64Url(new Uint8Array(signature))}`;
}
