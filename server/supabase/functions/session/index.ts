import { requireAppleUser } from "../_shared/appleAuth.ts";
import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { errorResponse, json, requireMethod } from "../_shared/respond.ts";
import { issueSessionToken } from "../_shared/sessionToken.ts";

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "POST");
  await enforceRateLimit(req, "session", buckets.session);
  const appleSubject = await requireAppleUser(req);

  const session = await issueSessionToken(appleSubject);
  return json({ token: session.token, expiresAt: session.expiresAt.toISOString() });
}

Deno.serve(async (req) => {
  try {
    return await handle(req);
  } catch (cause) {
    return errorResponse(cause);
  }
});
