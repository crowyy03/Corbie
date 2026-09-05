create table if not exists public.invites (
  code text primary key,
  space_id uuid not null,
  share_url text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  redeemed_at timestamptz
);

create index if not exists invites_space_id_idx on public.invites (space_id);
create index if not exists invites_expires_at_idx on public.invites (expires_at);

create table if not exists public.entitlements (
  space_id uuid primary key,
  original_transaction_id text,
  product_id text,
  status text not null default 'none'
    check (status in ('none', 'active', 'grace', 'expired', 'revoked')),
  expires_at timestamptz,
  payer_hash text,
  environment text not null default 'Production'
    check (environment in ('Sandbox', 'Production')),
  updated_at timestamptz not null default now()
);

create index if not exists entitlements_original_transaction_id_idx
  on public.entitlements (original_transaction_id);

create table if not exists public.events (
  id bigint generated always as identity primary key,
  anon_id uuid not null,
  name text not null,
  props jsonb not null default '{}'::jsonb,
  ts timestamptz not null default now(),
  app_version text,
  locale text,
  received_at timestamptz not null default now()
);

create index if not exists events_name_ts_idx on public.events (name, ts);
create index if not exists events_anon_id_ts_idx on public.events (anon_id, ts);

create table if not exists public.fx_rates (
  base text primary key,
  date date not null,
  rates jsonb not null,
  fetched_at timestamptz not null default now()
);

create table if not exists public.parse_cache (
  url_hash text primary key,
  payload jsonb not null,
  fetched_at timestamptz not null default now()
);

create index if not exists parse_cache_fetched_at_idx on public.parse_cache (fetched_at);

create table if not exists public.rate_limits (
  key text primary key,
  tokens int not null,
  updated_at timestamptz not null default now()
);

alter table public.invites enable row level security;
alter table public.entitlements enable row level security;
alter table public.events enable row level security;
alter table public.fx_rates enable row level security;
alter table public.parse_cache enable row level security;
alter table public.rate_limits enable row level security;

alter table public.invites force row level security;
alter table public.entitlements force row level security;
alter table public.events force row level security;
alter table public.fx_rates force row level security;
alter table public.parse_cache force row level security;
alter table public.rate_limits force row level security;

revoke all on public.invites from anon, authenticated;
revoke all on public.entitlements from anon, authenticated;
revoke all on public.events from anon, authenticated;
revoke all on public.fx_rates from anon, authenticated;
revoke all on public.parse_cache from anon, authenticated;
revoke all on public.rate_limits from anon, authenticated;

create or replace function public.rate_limit_take(
  p_key text,
  p_capacity int,
  p_refill_per_hour int
) returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tokens int;
  v_updated timestamptz;
  v_refill int;
begin
  insert into public.rate_limits (key, tokens, updated_at)
  values (p_key, p_capacity, now())
  on conflict (key) do nothing;

  select tokens, updated_at into v_tokens, v_updated
  from public.rate_limits
  where key = p_key
  for update;

  v_refill := floor(extract(epoch from (now() - v_updated)) * p_refill_per_hour / 3600.0);
  if v_refill > 0 then
    v_tokens := least(p_capacity, v_tokens + v_refill);
    v_updated := now();
  end if;

  if v_tokens <= 0 then
    update public.rate_limits set tokens = v_tokens, updated_at = v_updated where key = p_key;
    return false;
  end if;

  update public.rate_limits set tokens = v_tokens - 1, updated_at = v_updated where key = p_key;
  return true;
end;
$$;

revoke all on function public.rate_limit_take(text, int, int) from public, anon, authenticated;
grant execute on function public.rate_limit_take(text, int, int) to service_role;

create or replace function public.purge_expired_rows() returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.events where ts < now() - interval '30 days';
  delete from public.invites where created_at < now() - interval '1 day';
  delete from public.parse_cache where fetched_at < now() - interval '7 days';
  delete from public.rate_limits where updated_at < now() - interval '1 day';
end;
$$;

revoke all on function public.purge_expired_rows() from public, anon, authenticated;
grant execute on function public.purge_expired_rows() to service_role;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.unschedule('corbie_purge_expired_rows')
      where exists (select 1 from cron.job where jobname = 'corbie_purge_expired_rows');
    perform cron.schedule(
      'corbie_purge_expired_rows',
      '17 3 * * *',
      $cron$select public.purge_expired_rows();$cron$
    );
  end if;
exception
  when others then
    raise notice 'pg_cron scheduling skipped: %', sqlerrm;
end;
$$;
