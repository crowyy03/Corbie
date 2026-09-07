import { sha256Hex } from "./hash.ts";

export type EntitlementStatus =
  | "none"
  | "active"
  | "in_grace_period"
  | "in_billing_retry"
  | "expired"
  | "revoked";

export interface NotificationPayload {
  notificationType?: string;
  subtype?: string;
  notificationUUID?: string;
  signedDate?: number;
  data?: {
    environment?: string;
    bundleId?: string;
    signedTransactionInfo?: string;
    signedRenewalInfo?: string;
  };
}

export interface TransactionInfo {
  originalTransactionId?: string;
  productId?: string;
  appAccountToken?: string;
  expiresDate?: number;
  revocationDate?: number;
  environment?: string;
  bundleId?: string;
  transactionReason?: string;
  signedDate?: number;
}

export interface RenewalInfo {
  autoRenewProductId?: string;
  gracePeriodExpiresDate?: number;
  expirationIntent?: number;
  isInBillingRetryPeriod?: boolean;
  environment?: string;
  bundleId?: string;
}

const activeTypes = new Set([
  "SUBSCRIBED",
  "DID_RENEW",
  "DID_CHANGE_RENEWAL_STATUS",
  "OFFER_REDEEMED",
  "DID_CHANGE_RENEWAL_PREF",
  "PRICE_INCREASE",
  "RENEWAL_EXTENDED",
]);

const revokedTypes = new Set(["REFUND", "REVOKE"]);
const expiredTypes = new Set(["EXPIRED", "GRACE_PERIOD_EXPIRED"]);

export function mapNotificationToStatus(
  notificationType: string | undefined,
  subtype: string | undefined,
  transaction: TransactionInfo,
  renewal: RenewalInfo,
  now: number = Date.now(),
): EntitlementStatus {
  const type = notificationType ?? "";

  if (revokedTypes.has(type)) return "revoked";
  if (transaction.revocationDate !== undefined) return "revoked";
  if (expiredTypes.has(type)) return "expired";

  if (type === "DID_FAIL_TO_RENEW") {
    const grace = renewal.gracePeriodExpiresDate;
    if (grace !== undefined && grace > now) return "in_grace_period";
    if (grace === undefined && subtype === "GRACE_PERIOD") return "in_grace_period";
    if (renewal.isInBillingRetryPeriod === true) return "in_billing_retry";
    return "expired";
  }

  if (activeTypes.has(type)) {
    const expires = transaction.expiresDate;
    if (expires !== undefined && expires <= now) return "expired";
    return "active";
  }

  const expires = transaction.expiresDate;
  if (expires !== undefined) return expires > now ? "active" : "expired";
  return "none";
}

export function expiresAtOf(
  status: EntitlementStatus,
  transaction: TransactionInfo,
  renewal: RenewalInfo,
): string | null {
  const millis = status === "in_grace_period" || status === "in_billing_retry"
    ? renewal.gracePeriodExpiresDate ?? transaction.expiresDate
    : transaction.expiresDate;
  if (millis === undefined) return null;
  return new Date(millis).toISOString();
}

export function signedDateOf(
  payload: NotificationPayload,
  transaction: TransactionInfo,
): string | null {
  const millis = payload.signedDate ?? transaction.signedDate;
  if (millis === undefined || !Number.isFinite(millis)) return null;
  return new Date(millis).toISOString();
}

export function matchesBundle(value: string | undefined, bundleId: string): boolean {
  return value === undefined || value === bundleId;
}

export function normalizeEnvironment(raw: string | undefined): "Sandbox" | "Production" | null {
  if (raw === "Sandbox" || raw === "Production") return raw;
  return null;
}

export function payerHash(originalTransactionId: string | undefined): Promise<string | null> {
  if (!originalTransactionId) return Promise.resolve(null);
  return sha256Hex(`corbie:${originalTransactionId}`);
}
