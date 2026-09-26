import { normalizeInviteCode } from "../_shared/inviteCode.ts";
import { databaseInviteStore, redeemerOf, redeemInvite } from "../_shared/invites.ts";
import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { ApiError, json, pathSegments, requireMethod, serve } from "../_shared/respond.ts";

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "GET");
  await enforceRateLimit(req, "invite-redeem", buckets.inviteRedeem);

  const code = normalizeInviteCode(pathSegments(req, "invite-redeem")[0] ?? "");
  if (!code) throw new ApiError("not_found", "This code does not exist");

  return json(await redeemInvite(databaseInviteStore, code, await redeemerOf(req)));
}

serve(handle);
