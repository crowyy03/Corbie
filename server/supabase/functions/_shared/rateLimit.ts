import { ApiError } from "./respond.ts";
import { serviceClient } from "./supabase.ts";

export interface Bucket {
  capacity: number;
  refillPerHour: number;
}

export const buckets = {
  invite: { capacity: 30, refillPerHour: 30 },
  inviteRedeem: { capacity: 60, refillPerHour: 60 },
  parse: { capacity: 60, refillPerHour: 60 },
  fx: { capacity: 120, refillPerHour: 120 },
  events: { capacity: 600, refillPerHour: 600 },
  entitlement: { capacity: 240, refillPerHour: 240 },
  appleRevoke: { capacity: 10, refillPerHour: 10 },
} as const satisfies Record<string, Bucket>;

function trimmed(value: string | null): string | null {
  const result = value?.trim() ?? "";
  return result.length > 0 ? result : null;
}

async function digest(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0")).join("")
    .slice(0, 32);
}

export async function clientKey(req: Request): Promise<string> {
  const direct = trimmed(req.headers.get("cf-connecting-ip")) ??
    trimmed(req.headers.get("x-real-ip"));
  if (direct) return direct;

  const forwarded = trimmed(req.headers.get("x-forwarded-for"));
  const hops = forwarded?.split(",").map((hop) => hop.trim()).filter((hop) => hop.length > 0) ?? [];
  if (hops.length > 0) return hops[hops.length - 1];

  const anon = trimmed(req.headers.get("x-anon-id"));
  if (anon) return `anon:${await digest(anon)}`;
  return "unknown";
}

export async function enforceRateLimit(req: Request, route: string, bucket: Bucket): Promise<void> {
  const key = `${route}:${await clientKey(req)}`;
  const { data, error } = await serviceClient().rpc("rate_limit_take", {
    p_key: key,
    p_capacity: bucket.capacity,
    p_refill_per_hour: bucket.refillPerHour,
  });
  if (error) {
    console.error("rate_limit_take failed", error);
    return;
  }
  if (data === false) {
    throw new ApiError("rate_limited", "Too many requests, try again later");
  }
}
