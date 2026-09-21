alter table public.invites add column if not exists superseded_at timestamptz;
alter table public.invites add column if not exists redeemed_by text;

alter table public.invites drop constraint if exists invites_redeemed_by_digest;
alter table public.invites add constraint invites_redeemed_by_digest
  check (redeemed_by is null or redeemed_by ~ '^[0-9a-f]{32}$');
