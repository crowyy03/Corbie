import { verifyAppleJws } from "../_shared/appleJws.ts";
import { appleBundleId, appStoreAppAppleId } from "../_shared/appstore.ts";
import { appStoreServerApiFromEnv } from "../_shared/appStoreServerApi.ts";
import { defaultReconcileOptions, reconcileSubscriptions } from "../_shared/reconcile.ts";
import { ApiError, json, requireMethod, serve } from "../_shared/respond.ts";
import { requireServiceRole } from "../_shared/serviceRoleAuth.ts";
import { databaseSubscriptionStore } from "../_shared/subscriptions.ts";

async function historyDays(req: Request): Promise<number> {
  const text = await req.text();
  if (text.trim().length === 0) return defaultReconcileOptions.historyDays;
  let body: { days?: unknown };
  try {
    body = JSON.parse(text);
  } catch {
    throw new ApiError("invalid_request", "Body is not valid JSON");
  }
  if (body.days === undefined) return defaultReconcileOptions.historyDays;
  if (typeof body.days !== "number" || !Number.isInteger(body.days) || body.days < 1) {
    throw new ApiError("invalid_request", "days must be a whole number of days");
  }
  return body.days;
}

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "POST");
  await requireServiceRole(req);

  const report = await reconcileSubscriptions({
    verify: verifyAppleJws,
    bundleId: appleBundleId(),
    appAppleId: appStoreAppAppleId(),
    store: databaseSubscriptionStore(),
    appStoreApi: appStoreServerApiFromEnv(),
    now: () => new Date(),
  }, { ...defaultReconcileOptions, historyDays: await historyDays(req) });
  return json(report);
}

serve(handle);
