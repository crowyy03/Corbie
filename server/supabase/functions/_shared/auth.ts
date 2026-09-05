import { verifyAppleIdentityToken } from "./appleAuth.ts";
import { bearerToken } from "./respond.ts";
import { hashAppleSubject, isSessionToken, verifySessionToken } from "./sessionToken.ts";

export type AuthSource = "apple" | "session";

export interface AuthenticatedUser {
  subject: string;
  source: AuthSource;
}

export async function requireUser(
  req: Request,
  fetchImpl: typeof fetch = fetch,
): Promise<AuthenticatedUser> {
  const token = bearerToken(req);
  if (isSessionToken(token)) {
    return { subject: await verifySessionToken(token), source: "session" };
  }
  const appleSubject = await verifyAppleIdentityToken(token, fetchImpl);
  return { subject: await hashAppleSubject(appleSubject), source: "apple" };
}
