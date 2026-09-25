import type { EntitlementStatus, Environment } from "./appstore.ts";
import { ApiError } from "./respond.ts";
import { serviceClient } from "./supabase.ts";

export type SubscriptionEventKind = "state" | "revocation" | "reversal";

export type ApplyOutcome = "applied" | "linked" | "duplicate" | "stale" | "not_latest";

export interface RenewalState {
  autoRenew: boolean | null;
  gracePeriodExpiresAt: string | null;
}

export interface SubscriptionEvent {
  environment: Environment;
  originalTransactionId: string;
  kind: SubscriptionEventKind;
  spaceId: string | null;
  transactionId: string | null;
  productId: string | null;
  status: EntitlementStatus;
  expiresAt: string | null;
  revokedAt: string | null;
  offerType: number | null;
  renewal: RenewalState | null;
  signedDate: string | null;
  notificationUuid: string | null;
  checked: boolean;
}

export interface SpaceEntitlement {
  status: EntitlementStatus;
  productId: string | null;
  expiresAt: string | null;
  updatedAt: string | null;
}

export interface SubscriptionKey {
  environment: Environment;
  originalTransactionId: string;
}

export interface SubscriptionStore {
  apply(event: SubscriptionEvent): Promise<ApplyOutcome>;
  linkSpace(key: SubscriptionKey, spaceId: string): Promise<boolean>;
  entitlement(spaceId: string, environment: Environment): Promise<SpaceEntitlement | null>;
  dueForCheck(limit: number): Promise<SubscriptionKey[]>;
}

export type RpcArgs = Record<string, string | number | boolean | null>;

export interface Rpc {
  scalar(name: string, args: RpcArgs): Promise<unknown>;
  rows(name: string, args: RpcArgs): Promise<Record<string, unknown>[]>;
}

export function subscriptionApplyArgs(event: SubscriptionEvent): RpcArgs {
  return {
    p_environment: event.environment,
    p_original_transaction_id: event.originalTransactionId,
    p_kind: event.kind,
    p_space_id: event.spaceId,
    p_transaction_id: event.transactionId,
    p_product_id: event.productId,
    p_status: event.status,
    p_expires_at: event.expiresAt,
    p_revoked_at: event.revokedAt,
    p_offer_type: event.offerType,
    p_renewal_known: event.renewal !== null,
    p_auto_renew: event.renewal?.autoRenew ?? null,
    p_grace_period_expires_at: event.renewal?.gracePeriodExpiresAt ?? null,
    p_signed_date: event.signedDate,
    p_notification_uuid: event.notificationUuid,
    p_checked: event.checked,
  };
}

const applyOutcomes = new Set<ApplyOutcome>([
  "applied",
  "linked",
  "duplicate",
  "stale",
  "not_latest",
]);

function textOrNull(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

export function subscriptionStore(rpc: Rpc): SubscriptionStore {
  return {
    async apply(event) {
      const outcome = await rpc.scalar("subscription_apply", subscriptionApplyArgs(event));
      if (!applyOutcomes.has(outcome as ApplyOutcome)) {
        throw new ApiError("internal", "Could not store the subscription");
      }
      return outcome as ApplyOutcome;
    },

    async linkSpace(key, spaceId) {
      const linked = await rpc.scalar("subscription_link_space", {
        p_environment: key.environment,
        p_original_transaction_id: key.originalTransactionId,
        p_space_id: spaceId,
      });
      return linked === true;
    },

    async entitlement(spaceId, environment) {
      const rows = await rpc.rows("space_entitlement", {
        p_space_id: spaceId,
        p_environment: environment,
      });
      const row = rows[0];
      if (!row) return null;
      return {
        status: row.status as EntitlementStatus,
        productId: textOrNull(row.product_id),
        expiresAt: textOrNull(row.expires_at),
        updatedAt: textOrNull(row.updated_at),
      };
    },

    async dueForCheck(limit) {
      const rows = await rpc.rows("subscriptions_due_for_check", { p_limit: limit });
      return rows.map((row) => ({
        environment: row.environment as Environment,
        originalTransactionId: String(row.original_transaction_id),
      }));
    },
  };
}

async function callDatabase(name: string, args: RpcArgs): Promise<unknown> {
  const { data, error } = await serviceClient().rpc(name, args);
  if (error) {
    console.error(`${name} failed`, error);
    throw new ApiError("internal", "Could not reach the subscription store");
  }
  return data;
}

export const databaseRpc: Rpc = {
  scalar: callDatabase,
  async rows(name, args) {
    const data = await callDatabase(name, args);
    return Array.isArray(data) ? data as Record<string, unknown>[] : [];
  },
};

export function databaseSubscriptionStore(): SubscriptionStore {
  return subscriptionStore(databaseRpc);
}

export function entitlementBody(
  spaceId: string,
  environment: Environment,
  entitlement: SpaceEntitlement | null,
): Record<string, unknown> {
  return {
    spaceId,
    environment,
    status: entitlement?.status ?? "none",
    productId: entitlement?.productId ?? null,
    expiresAt: entitlement?.expiresAt ?? null,
    updatedAt: entitlement?.updatedAt ?? null,
  };
}
