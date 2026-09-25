import { verifyAppleJws } from "../_shared/appleJws.ts";
import { appleBundleId, appStoreAppAppleId } from "../_shared/appstore.ts";
import { appStoreServerApiFromEnv } from "../_shared/appStoreServerApi.ts";
import { requireUser } from "../_shared/auth.ts";
import { entitlementHandler } from "../_shared/entitlementEndpoint.ts";
import { enforceRateLimit } from "../_shared/rateLimit.ts";
import { serve } from "../_shared/respond.ts";
import { databaseSubscriptionStore } from "../_shared/subscriptions.ts";

serve(entitlementHandler({
  verify: verifyAppleJws,
  bundleId: appleBundleId(),
  appAppleId: appStoreAppAppleId(),
  store: databaseSubscriptionStore(),
  appStoreApi: appStoreServerApiFromEnv(),
  authenticate: (req) => requireUser(req),
  limit: enforceRateLimit,
  now: () => new Date(),
}));
