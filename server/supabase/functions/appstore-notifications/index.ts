import { verifyAppleJws } from "../_shared/appleJws.ts";
import {
  expiresAtOf,
  mapNotificationToStatus,
  normalizeEnvironment,
  type NotificationPayload,
  payerHash,
  type RenewalInfo,
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

  const signedTransaction = payload.data?.signedTransactionInfo;
  if (!signedTransaction) return empty(200);

  const transaction = await verifyAppleJws<TransactionInfo>(signedTransaction);
  const renewal: RenewalInfo = payload.data?.signedRenewalInfo
    ? await verifyAppleJws<RenewalInfo>(payload.data.signedRenewalInfo)
    : {};

  if (normalizeEnvironment(transaction.environment) !== expected) {
    throw new ApiError("invalid_request", `This endpoint only accepts ${expected} notifications`);
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

  const { error } = await serviceClient().from("entitlements").upsert({
    space_id: spaceId.toLowerCase(),
    original_transaction_id: transaction.originalTransactionId ?? null,
    product_id: transaction.productId ?? null,
    status,
    expires_at: expiresAtOf(status, transaction, renewal),
    payer_hash: await payerHash(transaction.originalTransactionId),
    environment: expected,
    updated_at: new Date().toISOString(),
  }, { onConflict: "space_id" });

  if (error) {
    console.error("entitlement upsert failed", error);
    throw new ApiError("internal", "Could not store the subscription");
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
