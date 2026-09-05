import { verifyAppleJws } from "../_shared/appleJws.ts";
import {
  expiresAtOf,
  mapNotificationToStatus,
  matchesBundle,
  normalizeEnvironment,
  type NotificationPayload,
  payerHash,
  type RenewalInfo,
  signedDateOf,
  type TransactionInfo,
} from "../_shared/appstore.ts";
import {
  ApiError,
  empty,
  errorResponse,
  isUuid,
  readJson,
  requireMethod,
} from "../_shared/respond.ts";
import { serviceClient } from "../_shared/supabase.ts";

function configuredEnvironment(): "Sandbox" | "Production" {
  return normalizeEnvironment(Deno.env.get("APPLE_ENV")) ?? "Production";
}

function configuredBundleId(): string {
  const value = Deno.env.get("APPLE_BUNDLE_ID");
  return value && value.length > 0 ? value : "app.corbie";
}

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "POST");

  const body = await readJson<{ signedPayload?: unknown }>(req);
  if (typeof body.signedPayload !== "string" || body.signedPayload.length === 0) {
    throw new ApiError("invalid_request", "signedPayload is required");
  }

  const payload = await verifyAppleJws<NotificationPayload>(body.signedPayload);
  const expected = configuredEnvironment();
  const environment = normalizeEnvironment(payload.data?.environment);
  if (environment !== expected) {
    throw new ApiError("invalid_request", `This endpoint only accepts ${expected} notifications`);
  }

  const bundleId = configuredBundleId();
  if (payload.data?.bundleId !== bundleId) {
    console.error("notification for another app", payload.notificationUUID);
    return empty(200);
  }

  const signedTransaction = payload.data?.signedTransactionInfo;
  if (!signedTransaction) return empty(200);

  const transaction = await verifyAppleJws<TransactionInfo>(signedTransaction);
  const renewal: RenewalInfo = payload.data?.signedRenewalInfo
    ? await verifyAppleJws<RenewalInfo>(payload.data.signedRenewalInfo)
    : {};

  if (normalizeEnvironment(transaction.environment) !== expected) {
    throw new ApiError("invalid_request", `This endpoint only accepts ${expected} notifications`);
  }

  if (
    !matchesBundle(transaction.bundleId, bundleId) || !matchesBundle(renewal.bundleId, bundleId)
  ) {
    console.error("notification for another app", payload.notificationUUID);
    return empty(200);
  }

  const spaceId = transaction.appAccountToken;
  if (!isUuid(spaceId)) {
    console.error("notification without a usable appAccountToken", payload.notificationUUID);
    return empty(200);
  }

  const status = mapNotificationToStatus(
    payload.notificationType,
    payload.subtype,
    transaction,
    renewal,
  );

  const { data, error } = await serviceClient().rpc("entitlement_apply", {
    p_space_id: spaceId.toLowerCase(),
    p_original_transaction_id: transaction.originalTransactionId ?? null,
    p_product_id: transaction.productId ?? null,
    p_status: status,
    p_expires_at: expiresAtOf(status, transaction, renewal),
    p_payer_hash: await payerHash(transaction.originalTransactionId),
    p_environment: expected,
    p_signed_date: signedDateOf(payload, transaction),
    p_notification_uuid: payload.notificationUUID ?? null,
  });

  if (error) {
    console.error("entitlement write failed", error);
    throw new ApiError("internal", "Could not store the subscription");
  }

  if (data === false) {
    console.error("notification is stale or already applied", payload.notificationUUID);
  }

  return empty(200);
}

Deno.serve(async (req) => {
  try {
    return await handle(req);
  } catch (cause) {
    return errorResponse(cause);
  }
});
