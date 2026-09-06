import { verifyAppleIdentityToken } from "./appleAuth.ts";
import { bearerToken } from "./respond.ts";
import { isSessionToken, verifySessionToken } from "./sessionToken.ts";

export async function requireUser(
  req: Request,
  fetchImpl: typeof fetch = fetch,
): Promise<void> {
  const token = bearerToken(req);
  if (isSessionToken(token)) {
    await verifySessionToken(token);
    return;
  }
  await verifyAppleIdentityToken(token, fetchImpl);
}
