import { appleBundleId, type Environment } from "./appstore.ts";
import { importEs256PrivateKey, signEs256Jwt } from "./es256.ts";

export const appStoreServerApiHosts: Record<Environment, string> = {
  Production: "https://api.storekit.apple.com",
  Sandbox: "https://api.storekit-sandbox.apple.com",
};

const audience = "appstoreconnect-v1";
const tokenLifetimeSeconds = 20 * 60;
const requestTimeoutMs = 10_000;

export interface AppStoreServerApiKey {
  issuerId: string;
  keyId: string;
  privateKeyPem: string;
  bundleId: string;
}

export interface LastTransaction {
  originalTransactionId?: string;
  status?: number;
  signedTransactionInfo?: string;
  signedRenewalInfo?: string;
}

export interface SubscriptionStatusResponse {
  environment?: string;
  bundleId?: string;
  appAppleId?: number;
  data?: { subscriptionGroupIdentifier?: string; lastTransactions?: LastTransaction[] }[];
}

export interface NotificationHistoryRequest {
  startDate: number;
  endDate: number;
  onlyFailures?: boolean;
  transactionId?: string;
}

export interface NotificationHistoryResponse {
  notificationHistory?: { signedPayload?: string }[];
  hasMore?: boolean;
  paginationToken?: string;
}

export interface TestNotificationStatus {
  signedPayload?: string;
  sendAttempts?: { attemptDate?: number; sendAttemptResult?: string }[];
}

export class AppStoreServerApiError extends Error {
  readonly status: number;
  readonly errorCode: number | null;

  constructor(status: number, errorCode: number | null, message: string) {
    super(message);
    this.name = "AppStoreServerApiError";
    this.status = status;
    this.errorCode = errorCode;
  }
}

function secret(name: string): string | null {
  const value = Deno.env.get(name)?.trim() ?? "";
  return value.length > 0 ? value : null;
}

export function appStoreServerApiKeyFromEnv(): AppStoreServerApiKey | null {
  const issuerId = secret("APPSTORE_ISSUER_ID");
  const keyId = secret("APPSTORE_KEY_ID");
  const privateKeyPem = secret("APPSTORE_PRIVATE_KEY");
  if (!issuerId || !keyId || !privateKeyPem) return null;
  return { issuerId, keyId, privateKeyPem, bundleId: appleBundleId() };
}

export async function buildAppStoreServerApiToken(
  key: AppStoreServerApiKey,
  now: Date = new Date(),
): Promise<string> {
  const signingKey = await importEs256PrivateKey(key.privateKeyPem, "APPSTORE_PRIVATE_KEY");
  const issuedAt = Math.floor(now.getTime() / 1000);
  return await signEs256Jwt(signingKey, { alg: "ES256", kid: key.keyId, typ: "JWT" }, {
    iss: key.issuerId,
    iat: issuedAt,
    exp: issuedAt + tokenLifetimeSeconds,
    aud: audience,
    bid: key.bundleId,
  });
}

export class AppStoreServerApi {
  readonly environment: Environment;
  private readonly key: AppStoreServerApiKey;
  private readonly fetchImpl: typeof fetch;
  private readonly now: () => Date;

  constructor(
    key: AppStoreServerApiKey,
    environment: Environment,
    fetchImpl: typeof fetch = fetch,
    now: () => Date = () => new Date(),
  ) {
    this.key = key;
    this.environment = environment;
    this.fetchImpl = fetchImpl;
    this.now = now;
  }

  getAllSubscriptionStatuses(transactionId: string): Promise<SubscriptionStatusResponse> {
    return this.request("GET", `/inApps/v1/subscriptions/${encodeURIComponent(transactionId)}`);
  }

  getTransactionInfo(transactionId: string): Promise<{ signedTransactionInfo?: string }> {
    return this.request("GET", `/inApps/v1/transactions/${encodeURIComponent(transactionId)}`);
  }

  getNotificationHistory(
    request: NotificationHistoryRequest,
    paginationToken?: string,
  ): Promise<NotificationHistoryResponse> {
    const query = paginationToken ? `?paginationToken=${encodeURIComponent(paginationToken)}` : "";
    return this.request("POST", `/inApps/v1/notifications/history${query}`, request);
  }

  requestTestNotification(): Promise<{ testNotificationToken?: string }> {
    return this.request("POST", "/inApps/v1/notifications/test");
  }

  getTestNotificationStatus(testNotificationToken: string): Promise<TestNotificationStatus> {
    return this.request(
      "GET",
      `/inApps/v1/notifications/test/${encodeURIComponent(testNotificationToken)}`,
    );
  }

  async setAppAccountToken(originalTransactionId: string, appAccountToken: string): Promise<void> {
    await this.request(
      "PUT",
      `/inApps/v1/transactions/${encodeURIComponent(originalTransactionId)}/appAccountToken`,
      { appAccountToken },
    );
  }

  private async request<T>(method: string, path: string, body?: unknown): Promise<T> {
    const token = await buildAppStoreServerApiToken(this.key, this.now());
    const headers: Record<string, string> = { authorization: `Bearer ${token}` };
    if (body !== undefined) headers["content-type"] = "application/json";

    const url = `${appStoreServerApiHosts[this.environment]}${path}`;
    let response: Response;
    try {
      response = await this.fetchImpl(url, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(requestTimeoutMs),
      });
    } catch (cause) {
      throw new AppStoreServerApiError(0, null, `${method} ${path} did not reach Apple: ${cause}`);
    }

    const text = await response.text();
    if (!response.ok) {
      let errorCode: number | null = null;
      try {
        const parsed = JSON.parse(text);
        if (typeof parsed?.errorCode === "number") errorCode = parsed.errorCode;
      } catch {
        errorCode = null;
      }
      throw new AppStoreServerApiError(
        response.status,
        errorCode,
        `${method} ${path} answered ${response.status}${errorCode ? ` ${errorCode}` : ""}`,
      );
    }
    if (text.length === 0) return {} as T;
    try {
      return JSON.parse(text) as T;
    } catch {
      throw new AppStoreServerApiError(response.status, null, `${method} ${path} sent no JSON`);
    }
  }
}

export type AppStoreServerApiFactory = (environment: Environment) => AppStoreServerApi | null;

export function appStoreServerApiFromEnv(): AppStoreServerApiFactory {
  const key = appStoreServerApiKeyFromEnv();
  return (environment) => key ? new AppStoreServerApi(key, environment) : null;
}
