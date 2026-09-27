import { verifyAppleJws } from "../_shared/appleJws.ts";
import { normalizeEnvironment } from "../_shared/appstore.ts";
import { AppStoreServerApi, appStoreServerApiKeyFromEnv } from "../_shared/appStoreServerApi.ts";
import { ApiError, json, readJson, requireMethod, serve } from "../_shared/respond.ts";
import { requireServiceRole } from "../_shared/serviceRoleAuth.ts";
import { requestAndAwaitTestNotification } from "../_shared/testNotification.ts";

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "POST");
  await requireServiceRole(req);

  const body = await readJson<{ environment?: unknown }>(req);
  const environment = typeof body.environment === "string"
    ? normalizeEnvironment(body.environment)
    : null;
  if (!environment) {
    throw new ApiError("invalid_request", "environment must be Sandbox or Production");
  }
  const key = appStoreServerApiKeyFromEnv();
  if (!key) throw new ApiError("internal", "Server is missing the App Store Server API key");

  const report = await requestAndAwaitTestNotification({
    api: new AppStoreServerApi(key, environment),
    verify: verifyAppleJws,
    sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  });
  return json(report, report.delivered ? 200 : 502);
}

serve(handle);
