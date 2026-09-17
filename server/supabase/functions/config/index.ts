import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { ApiError, json, requireMethod, serve } from "../_shared/respond.ts";
import { serviceClient } from "../_shared/supabase.ts";

const monetizationKey = "monetization_enabled";

interface AppConfigRow {
  value: unknown;
}

export interface AppConfigRead {
  data: AppConfigRow | null;
  error: unknown;
}

export function monetizationEnabledFrom(read: AppConfigRead): boolean {
  if (read.error) {
    console.error("app_config read failed", read.error);
    throw new ApiError("internal", "Could not read the app config");
  }
  if (!read.data) return false;
  if (typeof read.data.value !== "boolean") {
    console.error(
      `app_config ${monetizationKey} is not a JSON boolean: ${JSON.stringify(read.data.value)}`,
    );
    throw new ApiError("internal", "Could not read the app config");
  }
  return read.data.value;
}

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "GET");
  await enforceRateLimit(req, "config", buckets.config);

  const read = await serviceClient()
    .from("app_config")
    .select("value")
    .eq("key", monetizationKey)
    .maybeSingle<AppConfigRow>();
  return json({ monetizationEnabled: monetizationEnabledFrom(read) });
}

serve(handle);
