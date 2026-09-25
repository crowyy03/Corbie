import type { AppStoreServerApi } from "./appStoreServerApi.ts";
import {
  type EntitlementStatus,
  type Environment,
  isoDate,
  matchesBundle,
  normalizeEnvironment,
  type NotificationPayload,
  type RenewalInfo,
  type SignedDataVerifier,
  signedDateOf,
  statusFromAppleCode,
  statusFromNotificationType,
  type TransactionInfo,
} from "./appstore.ts";
import { isUuid } from "./respond.ts";
import type { RenewalState, SubscriptionEvent, SubscriptionEventKind } from "./subscriptions.ts";

export interface AppIdentity {
  verify: SignedDataVerifier;
  bundleId: string;
  appAppleId: number;
}

export interface SubscriptionSnapshot {
  event: SubscriptionEvent;
  appAccountToken: string | null;
}

export function spaceIdFrom(...tokens: (string | undefined)[]): string | null {
  const token = tokens.find((candidate) => isUuid(candidate));
  return token ? token.toLowerCase() : null;
}

function renewalState(renewal: RenewalInfo | null): RenewalState | null {
  if (!renewal) return null;
  return {
    autoRenew: renewal.autoRenewStatus === undefined ? null : renewal.autoRenewStatus === 1,
    gracePeriodExpiresAt: isoDate(renewal.gracePeriodExpiresDate),
  };
}

function statusFromExpiry(transaction: TransactionInfo, now: number): EntitlementStatus {
  const expires = transaction.expiresDate;
  if (expires === undefined) return "none";
  return expires > now ? "active" : "expired";
}

function kindOf(notificationType: string | undefined): SubscriptionEventKind {
  if (notificationType === "REFUND" || notificationType === "REVOKE") return "revocation";
  if (notificationType === "REFUND_REVERSED") return "reversal";
  return "state";
}

function statusOf(
  kind: SubscriptionEventKind,
  payload: NotificationPayload,
  transaction: TransactionInfo,
  renewal: RenewalInfo | null,
  now: number,
): EntitlementStatus {
  if (kind === "revocation") return "revoked";
  const reported = statusFromAppleCode(payload.data?.status);
  if (reported) return reported;
  if (kind === "reversal") return statusFromExpiry(transaction, now);
  return statusFromNotificationType(
    payload.notificationType,
    payload.subtype,
    transaction,
    renewal ?? {},
    now,
  );
}

function baseEvent(
  environment: Environment,
  originalTransactionId: string,
  transaction: TransactionInfo,
): Omit<
  SubscriptionEvent,
  | "kind"
  | "spaceId"
  | "status"
  | "revokedAt"
  | "renewal"
  | "signedDate"
  | "notificationUuid"
  | "checked"
> {
  return {
    environment,
    originalTransactionId,
    transactionId: transaction.transactionId ?? null,
    productId: transaction.productId ?? null,
    expiresAt: isoDate(transaction.expiresDate),
    offerType: transaction.offerType ?? null,
  };
}

export function eventFromNotification(
  payload: NotificationPayload,
  transaction: TransactionInfo & { originalTransactionId: string },
  renewal: RenewalInfo | null,
  environment: Environment,
  now: number,
): SubscriptionEvent {
  const kind = kindOf(payload.notificationType);
  return {
    ...baseEvent(environment, transaction.originalTransactionId, transaction),
    kind,
    spaceId: spaceIdFrom(transaction.appAccountToken, renewal?.appAccountToken),
    status: statusOf(kind, payload, transaction, renewal, now),
    revokedAt: kind === "reversal" ? null : isoDate(transaction.revocationDate),
    renewal: renewalState(renewal),
    signedDate: signedDateOf(payload, transaction),
    notificationUuid: payload.notificationUUID ?? null,
    checked: false,
  };
}

export function eventFromClientTransaction(
  transaction: TransactionInfo & { originalTransactionId: string },
  environment: Environment,
  now: number,
): SubscriptionEvent {
  const revoked = transaction.revocationDate !== undefined;
  return {
    ...baseEvent(environment, transaction.originalTransactionId, transaction),
    kind: revoked ? "revocation" : "state",
    spaceId: null,
    status: revoked ? "revoked" : statusFromExpiry(transaction, now),
    revokedAt: isoDate(transaction.revocationDate),
    renewal: null,
    signedDate: isoDate(transaction.signedDate),
    notificationUuid: null,
    checked: false,
  };
}

export function sameEnvironmentAndApp(
  environment: Environment,
  bundleId: string,
  transaction: TransactionInfo,
  renewal: RenewalInfo | null,
): boolean {
  if (normalizeEnvironment(transaction.environment) !== environment) return false;
  if (renewal?.environment !== undefined && renewal.environment !== environment) return false;
  return matchesBundle(transaction.bundleId, bundleId) &&
    matchesBundle(renewal?.bundleId, bundleId);
}

export async function fetchSubscriptionSnapshot(
  api: AppStoreServerApi,
  originalTransactionId: string,
  app: AppIdentity,
  requestedAt: Date,
): Promise<SubscriptionSnapshot> {
  const environment = api.environment;
  const response = await api.getAllSubscriptionStatuses(originalTransactionId);
  if (normalizeEnvironment(response.environment) !== environment) {
    throw new Error(`status response is not from ${environment}`);
  }
  if (!matchesBundle(response.bundleId, app.bundleId)) {
    throw new Error("status response is for another app");
  }
  if (
    environment === "Production" && response.appAppleId !== undefined &&
    response.appAppleId !== app.appAppleId
  ) {
    throw new Error("status response is for another app id");
  }

  const item = (response.data ?? [])
    .flatMap((group) => group.lastTransactions ?? [])
    .find((candidate) => candidate.originalTransactionId === originalTransactionId);
  if (!item?.signedTransactionInfo) {
    throw new Error(`status response has no subscription ${originalTransactionId}`);
  }

  const transaction = await app.verify<TransactionInfo>(item.signedTransactionInfo);
  const renewal = item.signedRenewalInfo
    ? await app.verify<RenewalInfo>(item.signedRenewalInfo)
    : null;
  if (!sameEnvironmentAndApp(environment, app.bundleId, transaction, renewal)) {
    throw new Error("status response transaction is for another environment or app");
  }

  const reported = statusFromAppleCode(item.status);
  return {
    event: {
      ...baseEvent(environment, originalTransactionId, transaction),
      kind: "state",
      spaceId: null,
      status: reported ?? statusFromExpiry(transaction, requestedAt.getTime()),
      revokedAt: isoDate(transaction.revocationDate),
      renewal: renewalState(renewal),
      signedDate: requestedAt.toISOString(),
      notificationUuid: null,
      checked: true,
    },
    appAccountToken: spaceIdFrom(renewal?.appAccountToken, transaction.appAccountToken),
  };
}
