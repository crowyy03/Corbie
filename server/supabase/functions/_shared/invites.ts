import { requireAnonId } from "./events.ts";
import { saltedDigest } from "./hash.ts";
import { generateInviteCode } from "./inviteCode.ts";
import { ApiError } from "./respond.ts";
import { serviceClient } from "./supabase.ts";

export const inviteLifetimeMs = 15 * 60 * 1000;
export const redeemReplayWindowMs = 15 * 60 * 1000;
const maxInsertAttempts = 5;
const maxClaimAttempts = 2;

export interface InviteRow {
  code: string;
  space_id: string;
  share_url: string;
  created_at: string;
  expires_at: string;
  superseded_at: string | null;
  redeemed_at: string | null;
  redeemed_by: string | null;
}

export interface NewInvite {
  code: string;
  space_id: string;
  share_url: string;
  created_at: string;
  expires_at: string;
}

export interface CreatedInvite {
  code: string;
  expiresAt: string;
}

export interface InviteShare {
  shareURL: string;
  spaceId: string;
}

export interface InviteStore {
  insert(invite: NewInvite): Promise<"inserted" | "code_taken">;
  supersedeOlder(spaceId: string, createdAt: Date): Promise<void>;
  find(code: string): Promise<InviteRow | null>;
  claim(code: string, redeemer: string | null, now: Date): Promise<InviteRow | null>;
}

export type Redeemability = { kind: "replay"; row: InviteRow } | { kind: "claim" };

export async function createInvite(
  store: InviteStore,
  spaceId: string,
  shareURL: string,
  now: Date = new Date(),
  nextCode: () => string = generateInviteCode,
): Promise<CreatedInvite> {
  const expiresAt = new Date(now.getTime() + inviteLifetimeMs).toISOString();
  for (let attempt = 0; attempt < maxInsertAttempts; attempt++) {
    const code = nextCode();
    const outcome = await store.insert({
      code,
      space_id: spaceId,
      share_url: shareURL,
      created_at: now.toISOString(),
      expires_at: expiresAt,
    });
    if (outcome === "inserted") {
      await store.supersedeOlder(spaceId, now);
      return { code, expiresAt };
    }
  }
  throw new ApiError("internal", "Could not create an invite");
}

export async function redeemerDigest(req: Request): Promise<string | null> {
  const header = req.headers.get("x-anon-id")?.trim() ?? "";
  if (header.length === 0) return null;
  return await saltedDigest(requireAnonId(header));
}

function isReplay(row: InviteRow, redeemer: string | null, now: Date): boolean {
  if (redeemer === null || row.redeemed_at === null || row.redeemed_by !== redeemer) return false;
  return now.getTime() - new Date(row.redeemed_at).getTime() <= redeemReplayWindowMs;
}

export function redeemability(
  row: InviteRow | null,
  redeemer: string | null,
  now: Date,
): Redeemability {
  if (!row) throw new ApiError("not_found", "This code does not exist");
  if (row.superseded_at !== null) {
    throw new ApiError("superseded", "A newer code replaced this one");
  }
  if (row.redeemed_at !== null) {
    if (isReplay(row, redeemer, now)) return { kind: "replay", row };
    throw new ApiError("redeemed", "This code has already been used");
  }
  if (new Date(row.expires_at) <= now) throw new ApiError("expired", "This code has expired");
  return { kind: "claim" };
}

function shareOf(row: InviteRow): InviteShare {
  return { shareURL: row.share_url, spaceId: row.space_id };
}

export async function redeemInvite(
  store: InviteStore,
  code: string,
  redeemer: string | null,
  now: Date = new Date(),
): Promise<InviteShare> {
  for (let attempt = 0; attempt < maxClaimAttempts; attempt++) {
    const verdict = redeemability(await store.find(code), redeemer, now);
    if (verdict.kind === "replay") return shareOf(verdict.row);
    const claimed = await store.claim(code, redeemer, now);
    if (claimed) return shareOf(claimed);
  }
  throw new ApiError("redeemed", "This code has already been used");
}

const inviteColumns =
  "code, space_id, share_url, created_at, expires_at, superseded_at, redeemed_at, redeemed_by";

export const databaseInviteStore: InviteStore = {
  async insert(invite) {
    const { error } = await serviceClient().from("invites").insert(invite);
    if (!error) return "inserted";
    if (error.code === "23505") return "code_taken";
    console.error("invite insert failed", error);
    throw new ApiError("internal", "Could not create an invite");
  },

  async supersedeOlder(spaceId, createdAt) {
    const moment = createdAt.toISOString();
    const { error } = await serviceClient()
      .from("invites")
      .update({ superseded_at: moment })
      .eq("space_id", spaceId)
      .lt("created_at", moment)
      .is("redeemed_at", null)
      .is("superseded_at", null)
      .gt("expires_at", moment);
    if (error) {
      console.error("invite supersede failed", error);
      throw new ApiError("internal", "Could not create an invite");
    }
  },

  async find(code) {
    const { data, error } = await serviceClient()
      .from("invites")
      .select(inviteColumns)
      .eq("code", code)
      .maybeSingle<InviteRow>();
    if (error) {
      console.error("invite lookup failed", error);
      throw new ApiError("internal", "Could not read the invite");
    }
    return data;
  },

  async claim(code, redeemer, now) {
    const { data, error } = await serviceClient()
      .from("invites")
      .update({ redeemed_at: now.toISOString(), redeemed_by: redeemer })
      .eq("code", code)
      .is("redeemed_at", null)
      .is("superseded_at", null)
      .gt("expires_at", now.toISOString())
      .select(inviteColumns)
      .maybeSingle<InviteRow>();
    if (error) {
      console.error("invite claim failed", error);
      throw new ApiError("internal", "Could not read the invite");
    }
    return data;
  },
};
