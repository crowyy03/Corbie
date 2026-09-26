import type {
  InviteRow,
  InviteStore,
  NewInvite,
} from "../../supabase/functions/_shared/invites.ts";

export class MemoryInviteStore implements InviteStore {
  readonly rows = new Map<string, InviteRow>();
  beforeNextClaim: (() => void) | null = null;

  add(row: Omit<NewInvite, "cloudkit_environment" | "owner_account"> & Partial<InviteRow>): void {
    this.rows.set(row.code, {
      cloudkit_environment: null,
      owner_account: null,
      superseded_at: null,
      redeemed_at: null,
      redeemed_by: null,
      ...row,
    });
  }

  row(code: string): InviteRow {
    const row = this.rows.get(code);
    if (!row) throw new Error(`no invite ${code}`);
    return row;
  }

  insert(invite: NewInvite): Promise<"inserted" | "code_taken"> {
    if (this.rows.has(invite.code)) return Promise.resolve("code_taken");
    this.add(invite);
    return Promise.resolve("inserted");
  }

  supersedeOlder(spaceId: string, createdAt: Date): Promise<void> {
    for (const row of this.rows.values()) {
      const live = row.redeemed_at === null && row.superseded_at === null &&
        new Date(row.expires_at) > createdAt;
      if (row.space_id === spaceId && new Date(row.created_at) < createdAt && live) {
        row.superseded_at = createdAt.toISOString();
      }
    }
    return Promise.resolve();
  }

  expireLive(spaceId: string, now: Date): Promise<void> {
    for (const row of this.rows.values()) {
      const live = row.redeemed_at === null && row.superseded_at === null &&
        new Date(row.expires_at) > now;
      if (row.space_id === spaceId && live) row.expires_at = now.toISOString();
    }
    return Promise.resolve();
  }

  find(code: string): Promise<InviteRow | null> {
    const row = this.rows.get(code);
    return Promise.resolve(row ? { ...row } : null);
  }

  claim(code: string, redeemer: string | null, now: Date): Promise<InviteRow | null> {
    const racing = this.beforeNextClaim;
    this.beforeNextClaim = null;
    racing?.();
    const row = this.rows.get(code);
    const claimable = row !== undefined && row.redeemed_at === null &&
      row.superseded_at === null && new Date(row.expires_at) > now;
    if (!claimable) return Promise.resolve(null);
    row.redeemed_at = now.toISOString();
    row.redeemed_by = redeemer;
    return Promise.resolve({ ...row });
  }
}
