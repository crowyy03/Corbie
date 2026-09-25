export type Environment = "Sandbox" | "Production";

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
    appAppleId?: number;
    status?: number;
    signedTransactionInfo?: string;
    signedRenewalInfo?: string;
  };
}

export interface TransactionInfo {
  transactionId?: string;
  originalTransactionId?: string;
  productId?: string;
  appAccountToken?: string;
  expiresDate?: number;
  revocationDate?: number;
  offerType?: number;
  environment?: string;
  bundleId?: string;
  signedDate?: number;
}

export interface RenewalInfo {
  originalTransactionId?: string;
  appAccountToken?: string;
  autoRenewStatus?: number;
  gracePeriodExpiresDate?: number;
  isInBillingRetryPeriod?: boolean;
  environment?: string;
  bundleId?: string;
}

export interface AppTransactionInfo {
  receiptType?: string;
  bundleId?: string;
}

export type SignedDataVerifier = <T>(jws: string) => Promise<T>;

const statusByAppleCode: Record<number, EntitlementStatus> = {
  1: "active",
  2: "expired",
  3: "in_billing_retry",
  4: "in_grace_period",
  5: "revoked",
};

export function statusFromAppleCode(code: number | undefined): EntitlementStatus | null {
  if (code === undefined) return null;
  return statusByAppleCode[code] ?? null;
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

export function statusFromNotificationType(
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

  const grace = renewal.gracePeriodExpiresDate;
  if (type === "DID_FAIL_TO_RENEW") {
    if (grace !== undefined && grace > now) return "in_grace_period";
    if (grace === undefined && subtype === "GRACE_PERIOD") return "in_grace_period";
    if (renewal.isInBillingRetryPeriod === true) return "in_billing_retry";
    return "expired";
  }

  const expires = transaction.expiresDate;
  if (activeTypes.has(type)) {
    if (expires !== undefined && expires <= now) {
      return grace !== undefined && grace > now ? "in_grace_period" : "expired";
    }
    return "active";
  }

  if (expires !== undefined) return expires > now ? "active" : "expired";
  return "none";
}

export function signedDateOf(
  payload: NotificationPayload,
  transaction: TransactionInfo,
): string | null {
  return isoDate(payload.signedDate ?? transaction.signedDate);
}

export function isoDate(millis: number | undefined): string | null {
  if (millis === undefined || !Number.isFinite(millis)) return null;
  return new Date(millis).toISOString();
}

export function matchesBundle(value: string | undefined, bundleId: string): boolean {
  return value === undefined || value === bundleId;
}

export function normalizeEnvironment(raw: string | undefined): Environment | null {
  if (raw === "Sandbox" || raw === "Production") return raw;
  return null;
}

export function appleBundleId(): string {
  return Deno.env.get("APPLE_BUNDLE_ID") || "app.corbie";
}

export function appStoreAppAppleId(): number {
  return Number(Deno.env.get("APPSTORE_APP_APPLE_ID") || "6812410537");
}
