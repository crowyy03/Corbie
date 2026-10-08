import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { ApiError, json, requireMethod, serve } from "../_shared/respond.ts";
import { serviceClient } from "../_shared/supabase.ts";

export const configKeys = {
  monetizationEnabled: "monetization_enabled",
  monetizationV2Enabled: "monetization_v2_enabled",
  freeDays: "free_days",
} as const;

export const defaultFreeDays = 3;

interface AppConfigRow {
  key: string;
  value: unknown;
}

export interface AppConfigRead {
  data: AppConfigRow[] | null;
  error: unknown;
}

export interface ConfigBody {
  monetizationEnabled: boolean;
  monetizationV2Enabled: boolean;
  freeDays: number;
}

function unreadable(key: string, expected: string, value: unknown): ApiError {
  console.error(`app_config ${key} is not ${expected}: ${JSON.stringify(value)}`);
  return new ApiError("internal", "Could not read the app config");
}

function flagFrom(values: Map<string, unknown>, key: string): boolean {
  if (!values.has(key)) return true;
  const value = values.get(key);
  if (typeof value !== "boolean") throw unreadable(key, "a JSON boolean", value);
  return value;
}

function freeDaysFrom(values: Map<string, unknown>): number {
  if (!values.has(configKeys.freeDays)) return defaultFreeDays;
  const value = values.get(configKeys.freeDays);
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) {
    throw unreadable(configKeys.freeDays, "a whole number of days", value);
  }
  return value;
}

export function configFrom(read: AppConfigRead): ConfigBody {
  if (read.error) {
    console.error("app_config read failed", read.error);
    throw new ApiError("internal", "Could not read the app config");
  }
  const values = new Map((read.data ?? []).map((row) => [row.key, row.value]));
  return {
    monetizationEnabled: flagFrom(values, configKeys.monetizationEnabled),
    monetizationV2Enabled: flagFrom(values, configKeys.monetizationV2Enabled),
    freeDays: freeDaysFrom(values),
  };
}

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "GET");
  await enforceRateLimit(req, "config", buckets.config);

  const read = await serviceClient()
    .from("app_config")
    .select("key, value")
    .in("key", Object.values(configKeys));
  return json(configFrom(read));
}

serve(handle);
