import { decodeBase64Url, encodeBase64Url } from "@std/encoding/base64url";
import { ApiError } from "./respond.ts";

const clockSkewSeconds = 60;

export interface JwtParts {
  header: Record<string, unknown>;
  claims: Record<string, unknown>;
  signingInput: string;
  signature: Uint8Array;
}

function decodeSegment(segment: string, label: string): Record<string, unknown> {
  let value: unknown;
  try {
    value = JSON.parse(new TextDecoder().decode(decodeBase64Url(segment)));
  } catch {
    throw new ApiError("unauthorized", `${label} is malformed`);
  }
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new ApiError("unauthorized", `${label} is malformed`);
  }
  return value as Record<string, unknown>;
}

export function parseJwt(token: string, label: string): JwtParts {
  const parts = token.split(".");
  if (parts.length !== 3) throw new ApiError("unauthorized", `${label} is malformed`);

  let signature: Uint8Array;
  try {
    signature = decodeBase64Url(parts[2]);
  } catch {
    throw new ApiError("unauthorized", `${label} is malformed`);
  }

  return {
    header: decodeSegment(parts[0], label),
    claims: decodeSegment(parts[1], label),
    signingInput: `${parts[0]}.${parts[1]}`,
    signature,
  };
}

export function jwtSegment(value: unknown): string {
  return encodeBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

export function assertClaims(
  claims: Record<string, unknown>,
  options: { issuer: string; label: string },
): string {
  const { issuer, label } = options;
  if (claims.iss !== issuer) throw new ApiError("unauthorized", `${label} issuer is wrong`);

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
