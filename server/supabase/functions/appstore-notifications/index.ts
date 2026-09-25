import { verifyAppleJws } from "../_shared/appleJws.ts";
import { appleBundleId, appStoreAppAppleId } from "../_shared/appstore.ts";
import { processNotification } from "../_shared/notifications.ts";
import { ApiError, empty, readJson, requireMethod, serve } from "../_shared/respond.ts";
import { databaseSubscriptionStore } from "../_shared/subscriptions.ts";

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "POST");

  const body = await readJson<{ signedPayload?: unknown }>(req);
  if (typeof body.signedPayload !== "string" || body.signedPayload.length === 0) {
    throw new ApiError("invalid_request", "signedPayload is required");
  }

  const result = await processNotification(body.signedPayload, {
    verify: verifyAppleJws,
    bundleId: appleBundleId(),
    appAppleId: appStoreAppAppleId(),
    store: databaseSubscriptionStore(),
    now: () => new Date(),
  });

  if ("ignored" in result) {
    console.error("notification ignored:", result.ignored, result.notificationUUID);
  } else if (result.applied !== "applied") {
    console.error("notification not applied:", result.applied, result.notificationUUID);
  }
  return empty(200);
}

serve(handle);
