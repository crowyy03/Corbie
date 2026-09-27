import { verifyAppleJws } from "../supabase/functions/_shared/appleJws.ts";
import { normalizeEnvironment } from "../supabase/functions/_shared/appstore.ts";
import {
  AppStoreServerApi,
  appStoreServerApiKeyFromEnv,
} from "../supabase/functions/_shared/appStoreServerApi.ts";
import { requestAndAwaitTestNotification } from "../supabase/functions/_shared/testNotification.ts";

const environment = normalizeEnvironment(Deno.args[0]);
if (!environment) {
  console.error("usage: request-test-notification.ts Sandbox|Production");
  Deno.exit(2);
}

const key = appStoreServerApiKeyFromEnv();
if (!key) {
  console.error("set APPSTORE_ISSUER_ID, APPSTORE_KEY_ID and APPSTORE_PRIVATE_KEY first");
  Deno.exit(2);
}

const report = await requestAndAwaitTestNotification({
  api: new AppStoreServerApi(key, environment),
  verify: verifyAppleJws,
  sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
});
console.info(JSON.stringify(report, null, 2));
Deno.exit(report.delivered ? 0 : 1);
