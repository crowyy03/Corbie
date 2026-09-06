import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { ApiError, json, requireMethod, serve } from "../_shared/respond.ts";
import { serviceClient } from "../_shared/supabase.ts";

const cacheTtlMs = 12 * 60 * 60 * 1000;
const upstreamTimeoutMs = 8000;

interface FxRow {
  base: string;
  date: string;
  rates: Record<string, number>;
  fetched_at: string;
}

interface FrankfurterResponse {
  base?: string;
  date?: string;
  rates?: Record<string, number>;
}

function requireBase(url: URL): string {
  const raw = (url.searchParams.get("base") ?? "USD").trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(raw)) {
    throw new ApiError("invalid_request", "base must be a 3 letter code");
  }
  return raw;
}

async function readCache(base: string): Promise<FxRow | null> {
  const { data, error } = await serviceClient()
    .from("fx_rates")
    .select("base, date, rates, fetched_at")
    .eq("base", base)
    .maybeSingle<FxRow>();
  if (error) {
    console.error("fx cache read failed", error);
    return null;
  }
  return data;
}

async function fetchRates(base: string): Promise<FrankfurterResponse> {
  const response = await fetch(`https://api.frankfurter.app/latest?base=${base}`, {
    signal: AbortSignal.timeout(upstreamTimeoutMs),
    headers: { accept: "application/json" },
  });
  if (!response.ok) {
    await response.body?.cancel();
    throw new ApiError("upstream_failed", "Rates are unavailable right now");
  }
  return await response.json() as FrankfurterResponse;
}

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "GET");
  await enforceRateLimit(req, "fx", buckets.fx);

  const base = requireBase(new URL(req.url));
  const cached = await readCache(base);
  const fresh = cached && Date.now() - new Date(cached.fetched_at).getTime() < cacheTtlMs;
  if (cached && fresh) {
    return json({ base: cached.base, date: cached.date, rates: cached.rates });
  }

  let payload: FrankfurterResponse;
  try {
    payload = await fetchRates(base);
  } catch (cause) {
    if (cached) return json({ base: cached.base, date: cached.date, rates: cached.rates });
    if (cause instanceof ApiError) throw cause;
    throw new ApiError("upstream_failed", "Rates are unavailable right now");
  }

  const rates = payload.rates ?? {};
  const date = payload.date ?? new Date().toISOString().slice(0, 10);
  if (Object.keys(rates).length === 0) {
    if (cached) return json({ base: cached.base, date: cached.date, rates: cached.rates });
    throw new ApiError("upstream_failed", "Rates are unavailable right now");
  }

  const { error } = await serviceClient()
    .from("fx_rates")
    .upsert({ base, date, rates, fetched_at: new Date().toISOString() }, { onConflict: "base" });
  if (error) console.error("fx cache write failed", error);

  return json({ base, date, rates });
}

serve(handle);
