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

export function clientIp(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) {
    const first = forwarded.split(",")[0].trim();
    if (first.length > 0) return first;
  }
  return req.headers.get("cf-connecting-ip") ?? req.headers.get("x-real-ip") ?? "unknown";
}

export async function enforceRateLimit(req: Request, route: string, bucket: Bucket): Promise<void> {
  const key = `${route}:${clientIp(req)}`;
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
