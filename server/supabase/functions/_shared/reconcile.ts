import type { AppStoreServerApiFactory, NotificationHistoryResponse } from "./appStoreServerApi.ts";
import type { Environment } from "./appstore.ts";
import { type NotificationDeps, processNotification } from "./notifications.ts";
import { fetchSubscriptionSnapshot } from "./subscriptionEvents.ts";

export interface ReconcileDeps extends NotificationDeps {
  appStoreApi: AppStoreServerApiFactory;
}

export interface ReconcileOptions {
  historyDays: number;
  checkLimit: number;
  historyPageLimit: number;
}

export interface ReconcileReport {
  configured: boolean;
  checked: number;
  changed: number;
  checkFailures: number;
  replayed: Record<Environment, number>;
  replayFailures: Record<Environment, number>;
}

export const defaultReconcileOptions: ReconcileOptions = {
  historyDays: 3,
  checkLimit: 60,
  historyPageLimit: 10,
};

const historyWindowDays: Record<Environment, number> = { Production: 179, Sandbox: 29 };
const dayMs = 24 * 60 * 60 * 1000;

async function recheckDueSubscriptions(
  deps: ReconcileDeps,
  options: ReconcileOptions,
  report: ReconcileReport,
): Promise<void> {
  for (const key of await deps.store.dueForCheck(options.checkLimit)) {
    const api = deps.appStoreApi(key.environment);
    if (!api) continue;
    try {
      const snapshot = await fetchSubscriptionSnapshot(
        api,
        key.originalTransactionId,
        deps,
        deps.now(),
      );
      const outcome = await deps.store.apply({
        ...snapshot.event,
        spaceId: snapshot.appAccountToken,
      });
      report.checked += 1;
      if (outcome === "applied" || outcome === "linked") report.changed += 1;
    } catch (cause) {
      report.checkFailures += 1;
      console.error("reconcile check failed", key.environment, key.originalTransactionId, cause);
    }
  }
}

async function replayMissedNotifications(
  environment: Environment,
  deps: ReconcileDeps,
  options: ReconcileOptions,
  report: ReconcileReport,
): Promise<void> {
  const api = deps.appStoreApi(environment);
  if (!api) return;
  const endDate = deps.now().getTime();
  const days = Math.min(Math.max(options.historyDays, 1), historyWindowDays[environment]);
  const request = { startDate: endDate - days * dayMs, endDate, onlyFailures: true };

  let paginationToken: string | undefined;
  for (let page = 0; page < options.historyPageLimit; page++) {
    let history: NotificationHistoryResponse;
    try {
      history = await api.getNotificationHistory(request, paginationToken);
    } catch (cause) {
      report.replayFailures[environment] += 1;
      console.error("notification history failed", environment, cause);
      return;
    }
    for (const item of history.notificationHistory ?? []) {
      if (!item.signedPayload) continue;
      try {
        await processNotification(item.signedPayload, deps);
        report.replayed[environment] += 1;
      } catch (cause) {
        report.replayFailures[environment] += 1;
        console.error("notification replay failed", environment, cause);
      }
    }
    if (!history.hasMore || !history.paginationToken) return;
    paginationToken = history.paginationToken;
  }
}

export async function reconcileSubscriptions(
  deps: ReconcileDeps,
  options: ReconcileOptions = defaultReconcileOptions,
): Promise<ReconcileReport> {
  const report: ReconcileReport = {
    configured: deps.appStoreApi("Production") !== null,
    checked: 0,
    changed: 0,
    checkFailures: 0,
    replayed: { Production: 0, Sandbox: 0 },
    replayFailures: { Production: 0, Sandbox: 0 },
  };
  if (!report.configured) return report;

  await recheckDueSubscriptions(deps, options, report);
  for (const environment of ["Production", "Sandbox"] as const) {
    await replayMissedNotifications(environment, deps, options, report);
  }
  return report;
}
