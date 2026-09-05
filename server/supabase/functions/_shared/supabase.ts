import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { requiredEnv } from "./respond.ts";

let cached: SupabaseClient | null = null;

export function serviceClient(): SupabaseClient {
  if (cached) return cached;
  cached = createClient(requiredEnv("SUPABASE_URL"), requiredEnv("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { "x-corbie-function": "1" } },
  });
  return cached;
}
