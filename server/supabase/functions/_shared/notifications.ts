import {
  normalizeEnvironment,
  type NotificationPayload,
  type RenewalInfo,
  type TransactionInfo,
} from "./appstore.ts";
import {
  type AppIdentity,
  eventFromNotification,
  sameEnvironmentAndApp,
} from "./subscriptionEvents.ts";
import type { ApplyOutcome, SubscriptionStore } from "./subscriptions.ts";

export interface NotificationDeps extends AppIdentity {
  store: SubscriptionStore;
  now: () => Date;
}

export type NotificationResult =
  | { applied: ApplyOutcome; notificationUUID: string | null }
  | { ignored: string; notificationUUID: string | null };

const typesThatChangeNothing = new Set(["TEST", "CONSUMPTION_REQUEST", "REFUND_DECLINED"]);

export async function processNotification(
  signedPayload: string,
  deps: NotificationDeps,
): Promise<NotificationResult> {
  const payload = await deps.verify<NotificationPayload>(signedPayload);
  const notificationUUID = payload.notificationUUID ?? null;
  const ignored = (reason: string): NotificationResult => ({ ignored: reason, notificationUUID });

  const data = payload.data;
  if (!data) return ignored(`${payload.notificationType} carries no subscription data`);

  const environment = normalizeEnvironment(data.environment);
  if (!environment) return ignored(`unknown environment ${data.environment}`);
  if (data.bundleId !== deps.bundleId) return ignored(`notification for bundle ${data.bundleId}`);
  if (environment === "Production" && data.appAppleId !== deps.appAppleId) {
    return ignored(`notification for app ${data.appAppleId}`);
  }

  const type = payload.notificationType ?? "";
  if (typesThatChangeNothing.has(type)) return ignored(`${type} changes nothing`);
  if (!data.signedTransactionInfo) return ignored(`${type} carries no transaction`);

  const transaction = await deps.verify<TransactionInfo>(data.signedTransactionInfo);
  const renewal = data.signedRenewalInfo
    ? await deps.verify<RenewalInfo>(data.signedRenewalInfo)
    : null;

  if (!sameEnvironmentAndApp(environment, deps.bundleId, transaction, renewal)) {
    return ignored("transaction is for another environment or app");
  }
  const originalTransactionId = transaction.originalTransactionId;
  if (!originalTransactionId) return ignored("transaction has no originalTransactionId");
  if (transaction.expiresDate === undefined) return ignored("not an auto-renewable subscription");

  const event = eventFromNotification(
    payload,
    { ...transaction, originalTransactionId },
    renewal,
    environment,
    deps.now().getTime(),
  );
  return { applied: await deps.store.apply(event), notificationUUID };
}
