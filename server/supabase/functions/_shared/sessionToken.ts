import { encodeBase64Url } from "@std/encoding/base64url";
import { sha256Hex } from "./hash.ts";
import { parseJwt } from "./jwt.ts";
import { ApiError } from "./respond.ts";

export const sessionIssuer = "corbie";
export const sessionLifetimeSeconds = 180 * 24 * 60 * 60;

const clockSkewSeconds = 60;
const label = "Session token";

export interface IssuedSession {
  token: string;
  expiresAt: Date;
}

async function hmacKey(usage: KeyUsage): Promise<CryptoKey | null> {
  const secret = Deno.env.get("SESSION_SECRET") ?? "";
  if (secret.length === 0) return null;
  return await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    [usage],
  );
}

function encodeSegment(value: unknown): string {
  return encodeBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

export function hashAppleSubject(subject: string): Promise<string> {
  return sha256Hex(subject);
}

export function isSessionToken(token: string): boolean {
  const { header, claims } = parseJwt(token, "Token");
  return header.alg === "HS256" || claims.iss === sessionIssuer;
}

export async function issueSessionToken(appleSubject: string): Promise<IssuedSession> {
  const key = await hmacKey("sign");
  if (!key) throw new ApiError("internal", "Server is missing SESSION_SECRET");

  const issuedAt = Math.floor(Date.now() / 1000);
  const expiresAt = issuedAt + sessionLifetimeSeconds;
  const claims = {
    iss: sessionIssuer,
    sub: await hashAppleSubject(appleSubject),
    iat: issuedAt,
    exp: expiresAt,
  };
  const signingInput = `${encodeSegment({ alg: "HS256", typ: "JWT" })}.${encodeSegment(claims)}`;
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signingInput),
  );

  return {
    token: `${signingInput}.${encodeBase64Url(new Uint8Array(signature))}`,
    expiresAt: new Date(expiresAt * 1000),
  };
}

export async function verifySessionToken(token: string): Promise<string> {
  const key = await hmacKey("verify");
  if (!key) throw new ApiError("unauthorized", "Session tokens are not accepted");

  const { header, claims, signingInput, signature } = parseJwt(token, label);
  if (header.alg !== "HS256") throw new ApiError("unauthorized", "Unsupported token algorithm");

  const valid = await crypto.subtle.verify(
    "HMAC",
    key,
    signature as BufferSource,
    new TextEncoder().encode(signingInput),
  );
  if (!valid) throw new ApiError("unauthorized", `${label} signature is invalid`);

  if (claims.iss !== sessionIssuer) throw new ApiError("unauthorized", `${label} issuer is wrong`);

  const now = Math.floor(Date.now() / 1000);
  if (typeof claims.exp !== "number" || claims.exp + clockSkewSeconds < now) {
    throw new ApiError("unauthorized", `${label} has expired`);
  }
  if (typeof claims.iat === "number" && claims.iat - clockSkewSeconds > now) {
    throw new ApiError("unauthorized", `${label} is not valid yet`);
  }

  const subject = claims.sub;
  if (typeof subject !== "string" || subject.length === 0) {
    throw new ApiError("unauthorized", `${label} has no subject`);
  }
  return subject;
}
