import { type Environment, normalizeEnvironment } from "./appstore.ts";
import { type AppStoreServerApi, AppStoreServerApiError } from "./appStoreServerApi.ts";

export interface TestNotificationReport {
  environment: Environment;
  testNotificationToken: string;
  sendAttempts: string[];
  delivered: boolean;
  signedPayload: {
    notificationType: string | null;
    environment: Environment | null;
    bundleId: string | null;
  } | null;
}

interface TestPayload {
  notificationType?: string;
  data?: { environment?: string; bundleId?: string };
}

export interface TestNotificationDeps {
  api: Pick<
    AppStoreServerApi,
    "environment" | "requestTestNotification" | "getTestNotificationStatus"
  >;
  verify: <T>(jws: string) => Promise<T>;
  sleep: (ms: number) => Promise<void>;
}

export const statusChecks = 12;
export const statusIntervalMs = 5000;

export async function requestAndAwaitTestNotification(
  deps: TestNotificationDeps,
): Promise<TestNotificationReport> {
  const { testNotificationToken } = await deps.api.requestTestNotification();
  if (!testNotificationToken) {
    throw new Error("Apple accepted the request but sent no testNotificationToken");
  }
  const report: TestNotificationReport = {
    environment: deps.api.environment,
    testNotificationToken,
    sendAttempts: [],
    delivered: false,
    signedPayload: null,
  };
  for (let check = 0; check < statusChecks; check++) {
    await deps.sleep(statusIntervalMs);
    let status;
    try {
      status = await deps.api.getTestNotificationStatus(testNotificationToken);
    } catch (error) {
      if (error instanceof AppStoreServerApiError && error.status === 404) continue;
      throw error;
    }
    report.sendAttempts = (status.sendAttempts ?? []).map((sent) =>
      sent.sendAttemptResult ?? "UNKNOWN"
    );
    if (status.signedPayload) {
      const payload = await deps.verify<TestPayload>(status.signedPayload);
      report.signedPayload = {
        notificationType: payload.notificationType ?? null,
        environment: normalizeEnvironment(payload.data?.environment),
        bundleId: payload.data?.bundleId ?? null,
      };
    }
    if (report.sendAttempts.length > 0) break;
  }
  report.delivered = report.sendAttempts.includes("SUCCESS");
  return report;
}
