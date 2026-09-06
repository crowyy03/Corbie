import { normalizeInviteCode } from "../_shared/inviteCode.ts";
import { buckets, enforceRateLimit } from "../_shared/rateLimit.ts";
import { ApiError, json, pathSegments, requireMethod, serve } from "../_shared/respond.ts";
import { serviceClient } from "../_shared/supabase.ts";

interface InviteRow {
  space_id: string;
  share_url: string;
  expires_at: string;
  redeemed_at: string | null;
}

async function handle(req: Request): Promise<Response> {
  requireMethod(req, "GET");
  await enforceRateLimit(req, "invite-redeem", buckets.inviteRedeem);

  const segments = pathSegments(req, "invite-redeem");
  const raw = segments[0] ?? "";
  const code = normalizeInviteCode(raw);
  if (!code) throw new ApiError("not_found", "This code does not exist");

  const client = serviceClient();
  const found = await client
    .from("invites")
    .select("space_id, share_url, expires_at, redeemed_at")
    .eq("code", code)
    .maybeSingle<InviteRow>();
  if (found.error) {
    console.error("invite lookup failed", found.error);
    throw new ApiError("internal", "Could not read the invite");
  }
  if (!found.data) throw new ApiError("not_found", "This code does not exist");
  if (found.data.redeemed_at) throw new ApiError("redeemed", "This code has already been used");

  const now = new Date();
  if (new Date(found.data.expires_at) <= now) {
    throw new ApiError("expired", "This code has expired");
  }

  const claimed = await client
    .from("invites")
    .update({ redeemed_at: now.toISOString() })
    .eq("code", code)
    .is("redeemed_at", null)
    .gt("expires_at", now.toISOString())
    .select("space_id, share_url")
    .maybeSingle<Pick<InviteRow, "space_id" | "share_url">>();
  if (claimed.error) {
    console.error("invite claim failed", claimed.error);
    throw new ApiError("internal", "Could not read the invite");
  }
  if (!claimed.data) throw new ApiError("redeemed", "This code has already been used");

  return json({ shareURL: claimed.data.share_url, spaceId: claimed.data.space_id });
}

serve(handle);
