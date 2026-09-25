import { encodeBase64 } from "@std/encoding/base64";
import { decodeBase64Url, encodeBase64Url } from "@std/encoding/base64url";
import type {
  AppTransactionInfo,
  Environment,
  NotificationPayload,
  RenewalInfo,
  SignedDataVerifier,
  TransactionInfo,
} from "../../supabase/functions/_shared/appstore.ts";
import type { AppStoreServerApiKey } from "../../supabase/functions/_shared/appStoreServerApi.ts";
import { ApiError } from "../../supabase/functions/_shared/respond.ts";

export const bundleId = "app.corbie";
export const appAppleId = 6812410537;
export const hour = 60 * 60 * 1000;
export const day = 24 * hour;

function segment(value: unknown): string {
  return encodeBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

export function unsignedJws(payload: unknown): string {
  return `${segment({ alg: "ES256", x5c: [] })}.${segment(payload)}.unsigned`;
}

export const readUnsigned: SignedDataVerifier = <T>(jws: string): Promise<T> => {
  const parts = jws.split(".");
  if (parts.length !== 3 || parts[2] !== "unsigned") {
    return Promise.reject(new ApiError("unauthorized", "Signed payload signature is invalid"));
  }
  return Promise.resolve(JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[1]))) as T);
};

export function transaction(
  environment: Environment,
  fields: TransactionInfo & { originalTransactionId: string },
): TransactionInfo {
  return {
    transactionId: fields.originalTransactionId,
    productId: "app.corbie.monthly",
    bundleId,
    environment,
    ...fields,
  };
}

export interface NotificationFixture {
  type: string;
  subtype?: string;
  environment: Environment;
  uuid: string;
  signedDate: number;
  status?: number;
  appAppleId?: number;
  bundleId?: string;
  transaction?: TransactionInfo;
  renewal?: RenewalInfo;
}

export function notification(fixture: NotificationFixture): string {
  const payload: NotificationPayload = {
    notificationType: fixture.type,
    subtype: fixture.subtype,
    notificationUUID: fixture.uuid,
    signedDate: fixture.signedDate,
    data: {
      environment: fixture.environment,
      bundleId: fixture.bundleId ?? bundleId,
      appAppleId: fixture.environment === "Production"
        ? (fixture.appAppleId ?? appAppleId)
        : fixture.appAppleId,
      status: fixture.status,
      signedTransactionInfo: fixture.transaction ? unsignedJws(fixture.transaction) : undefined,
      signedRenewalInfo: fixture.renewal ? unsignedJws(fixture.renewal) : undefined,
    },
  };
  return unsignedJws(payload);
}

export function appTransactionProof(fields: AppTransactionInfo): string {
  return unsignedJws(fields);
}

export async function testApiKey(): Promise<{ key: AppStoreServerApiKey; publicKey: CryptoKey }> {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, [
    "sign",
    "verify",
  ]) as CryptoKeyPair;
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  return {
    key: {
      issuerId: "57246542-96fe-1a63-e053-0824d011072a",
      keyId: "2X9R4HXF34",
      privateKeyPem: `-----BEGIN PRIVATE KEY-----\n${
        encodeBase64(pkcs8)
      }\n-----END PRIVATE KEY-----`,
      bundleId,
    },
    publicKey: pair.publicKey,
  };
}

export interface RecordedCall {
  method: string;
  url: string;
  authorization: string | null;
  body: unknown;
}

export type AppleRoute = (call: RecordedCall) => Response | null;

export function appleFetch(routes: AppleRoute[], calls: RecordedCall[]): typeof fetch {
  return async (input, init) => {
    const text = typeof init?.body === "string" ? init.body : "";
    const call: RecordedCall = {
      method: init?.method ?? "GET",
      url: String(input),
      authorization: new Headers(init?.headers).get("authorization"),
      body: text.length > 0 ? JSON.parse(text) : null,
    };
    calls.push(call);
    for (const route of routes) {
      const response = route(call);
      if (response) return await Promise.resolve(response);
    }
    return new Response(JSON.stringify({ errorCode: 4040010, errorMessage: "not found" }), {
      status: 404,
    });
  };
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
