import type { AppStoreServerApiFactory } from "./appStoreServerApi.ts";
import {
  type AppTransactionInfo,
  type Environment,
  normalizeEnvironment,
  type TransactionInfo,
} from "./appstore.ts";
import type { Bucket } from "./rateLimit.ts";
import { buckets } from "./rateLimit.ts";
import { ApiError, json, pathSegments, readJson, requireMethod, requireUuid } from "./respond.ts";
import {
  type AppIdentity,
  eventFromClientTransaction,
  fetchSubscriptionSnapshot,
  sameEnvironmentAndApp,
  spaceIdFrom,
  type SubscriptionSnapshot,
} from "./subscriptionEvents.ts";
import { entitlementBody, type SubscriptionStore } from "./subscriptions.ts";

export const appTransactionHeader = "x-app-transaction";
const maxSignedLength = 20_000;

export interface EntitlementDeps extends AppIdentity {
  store: SubscriptionStore;
  appStoreApi: AppStoreServerApiFactory;
  authenticate: (req: Request) => Promise<void>;
  limit: (req: Request, route: string, bucket: Bucket) => Promise<void>;
  now: () => Date;
}

export async function callerEnvironment(
  req: Request,
  app: Pick<AppIdentity, "verify" | "bundleId">,
): Promise<Environment> {
  const proof = req.headers.get(appTransactionHeader)?.trim() ?? "";
  if (proof.length === 0 || proof.length > maxSignedLength) return "Production";

  let appTransaction: AppTransactionInfo;
  try {
    appTransaction = await app.verify<AppTransactionInfo>(proof);
  } catch {
    return "Production";
  }
  if (appTransaction.bundleId !== app.bundleId) return "Production";
  return normalizeEnvironment(appTransaction.receiptType) === "Sandbox" ? "Sandbox" : "Production";
}

async function readEntitlement(
  req: Request,
  spaceSegment: string | undefined,
  deps: EntitlementDeps,
): Promise<Response> {
  await deps.limit(req, "entitlement", buckets.entitlement);
  await deps.authenticate(req);

  const spaceId = requireUuid(spaceSegment, "spaceId");
  const environment = await callerEnvironment(req, deps);
  return json(
    entitlementBody(spaceId, environment, await deps.store.entitlement(spaceId, environment)),
  );
}

function requireSignedTransaction(value: unknown): string {
  if (typeof value !== "string" || value.length === 0 || value.length > maxSignedLength) {
    throw new ApiError("invalid_request", "signedTransaction is required");
  }
  return value;
}

async function snapshotOrNull(
  deps: EntitlementDeps,
  environment: Environment,
  originalTransactionId: string,
): Promise<SubscriptionSnapshot | null> {
  const api = deps.appStoreApi(environment);
  if (!api) return null;
  try {
    return await fetchSubscriptionSnapshot(api, originalTransactionId, deps, deps.now());
  } catch (cause) {
    console.error("subscription status lookup failed", cause);
    return null;
  }
}

async function pointSubscriptionAt(
  deps: EntitlementDeps,
  environment: Environment,
  originalTransactionId: string,
  spaceId: string,
): Promise<boolean> {
  const api = deps.appStoreApi(environment);
  if (!api) return false;
  try {
    await api.setAppAccountToken(originalTransactionId, spaceId);
    return true;
  } catch (cause) {
    console.error("setting the app account token failed", cause);
    return false;
  }
}

async function syncEntitlement(req: Request, deps: EntitlementDeps): Promise<Response> {
  await deps.limit(req, "entitlement-sync", buckets.entitlementSync);
  await deps.authenticate(req);

  const body = await readJson<{ spaceId?: unknown; signedTransaction?: unknown }>(req);
  const spaceId = requireUuid(body.spaceId, "spaceId");
  const signedTransaction = requireSignedTransaction(body.signedTransaction);
  const callerIs = await callerEnvironment(req, deps);

  const transaction = await deps.verify<TransactionInfo>(signedTransaction);
  const originalTransactionId = transaction.originalTransactionId;
  if (!originalTransactionId || transaction.expiresDate === undefined) {
    throw new ApiError("invalid_request", "signedTransaction is not a subscription");
  }
  const environment = normalizeEnvironment(transaction.environment);
  if (environment === null) {
    throw new ApiError("invalid_request", "signedTransaction names no environment");
  }
  if (!sameEnvironmentAndApp(environment, deps.bundleId, transaction, null)) {
    throw new ApiError("invalid_request", "signedTransaction is for another app");
  }

  const key = { environment, originalTransactionId };
  const snapshot = await snapshotOrNull(deps, environment, originalTransactionId);
  await deps.store.apply(
    snapshot?.event ??
      eventFromClientTransaction(
        { ...transaction, originalTransactionId },
        environment,
        deps.now().getTime(),
      ),
  );

  const appleToken = snapshot ? snapshot.appAccountToken : spaceIdFrom(transaction.appAccountToken);
  const pointed = appleToken === spaceId ||
    await pointSubscriptionAt(deps, environment, originalTransactionId, spaceId);
  await deps.store.linkSpace(key, spaceId);
  const reconciled = snapshot !== null && pointed;

  const entitlement = await deps.store.entitlement(spaceId, callerIs);
  return json({ ...entitlementBody(spaceId, callerIs, entitlement), reconciled });
}

export function entitlementHandler(deps: EntitlementDeps): (req: Request) => Promise<Response> {
  return async (req) => {
    const segments = pathSegments(req, "entitlement");
    if (segments[0] === "sync") {
      requireMethod(req, "POST");
      return await syncEntitlement(req, deps);
    }
    requireMethod(req, "GET");
    return await readEntitlement(req, segments[0], deps);
  };
}
