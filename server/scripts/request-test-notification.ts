import { normalizeEnvironment } from "../supabase/functions/_shared/appstore.ts";
import {
  AppStoreServerApi,
  AppStoreServerApiError,
  appStoreServerApiKeyFromEnv,
} from "../supabase/functions/_shared/appStoreServerApi.ts";

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

const api = new AppStoreServerApi(key, environment);
const { testNotificationToken } = await api.requestTestNotification();
if (!testNotificationToken) {
  console.error("Apple accepted the request but sent no testNotificationToken");
  Deno.exit(1);
}
console.log(`${environment} TEST notification requested, token ${testNotificationToken}`);

for (let attempt = 0; attempt < 12; attempt++) {
  await new Promise((resolve) => setTimeout(resolve, 5000));
  try {
    const status = await api.getTestNotificationStatus(testNotificationToken);
    const results = (status.sendAttempts ?? []).map((sent) => sent.sendAttemptResult);
    console.log(`send attempts: ${results.join(", ") || "none yet"}`);
    if (results.length > 0) Deno.exit(results.includes("SUCCESS") ? 0 : 1);
  } catch (error) {
    if (!(error instanceof AppStoreServerApiError) || error.status !== 404) throw error;
    console.log("status not available yet");
  }
}
console.error("no send attempt recorded within a minute");
Deno.exit(1);
