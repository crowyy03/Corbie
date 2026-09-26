alter table public.invites add column if not exists cloudkit_environment text;
alter table public.invites add column if not exists owner_account text;

alter table public.invites drop constraint if exists invites_cloudkit_environment_known;
alter table public.invites add constraint invites_cloudkit_environment_known
  check (cloudkit_environment is null or cloudkit_environment in ('development', 'production'));

alter table public.invites drop constraint if exists invites_owner_account_digest;
alter table public.invites add constraint invites_owner_account_digest
  check (owner_account is null or owner_account ~ '^[0-9a-f]{32}$');
