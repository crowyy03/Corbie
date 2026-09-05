import { decodeBase64Url } from "@std/encoding/base64url";
import { ApiError } from "./respond.ts";

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
