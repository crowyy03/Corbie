export type EntitlementStatus = "none" | "active" | "grace" | "expired" | "revoked";

export interface NotificationPayload {
  notificationType?: string;
  subtype?: string;
  notificationUUID?: string;
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
}

export interface RenewalInfo {
  autoRenewProductId?: string;
  gracePeriodExpiresDate?: number;
  expirationIntent?: number;
  isInBillingRetryPeriod?: boolean;
  environment?: string;
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
    if (grace !== undefined) return grace > now ? "grace" : "expired";
    return subtype === "GRACE_PERIOD" ? "grace" : "expired";
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
  const millis = status === "grace"
    ? renewal.gracePeriodExpiresDate ?? transaction.expiresDate
    : transaction.expiresDate;
  if (millis === undefined) return null;
  return new Date(millis).toISOString();
}

export function normalizeEnvironment(raw: string | undefined): "Sandbox" | "Production" | null {
  if (raw === "Sandbox" || raw === "Production") return raw;
  return null;
}

export async function payerHash(originalTransactionId: string | undefined): Promise<string | null> {
  if (!originalTransactionId) return null;
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`corbie:${originalTransactionId}`),
  );
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
