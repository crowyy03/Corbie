create table if not exists public.subscriptions (
  environment text not null check (environment in ('Sandbox', 'Production')),
  original_transaction_id text not null,
  space_id uuid,
  space_linked_at timestamptz,
  product_id text,
  status text not null
    check (status in ('none', 'active', 'in_grace_period', 'in_billing_retry', 'expired', 'revoked')),
  expires_at timestamptz,
  grace_period_expires_at timestamptz,
  entitlement_expires_at timestamptz generated always as (
    case
      when status in ('in_grace_period', 'in_billing_retry')
        then coalesce(grace_period_expires_at, expires_at)
      else expires_at
    end
  ) stored,
  auto_renew boolean,
  offer_type smallint,
  latest_transaction_id text,
  revoked_at timestamptz,
  last_notification_uuid text,
  signed_date timestamptz,
  checked_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (environment, original_transaction_id)
);

create index if not exists subscriptions_space_idx on public.subscriptions (space_id, environment);

alter table public.subscriptions enable row level security;
alter table public.subscriptions force row level security;
revoke all on public.subscriptions from anon, authenticated;
grant select, insert, update, delete on public.subscriptions to service_role;

insert into public.subscriptions (
  environment,
  original_transaction_id,
  space_id,
  space_linked_at,
  product_id,
  status,
  expires_at,
  grace_period_expires_at,
  last_notification_uuid,
  signed_date,
  updated_at
)
select distinct on (environment, original_transaction_id)
  environment,
  original_transaction_id,
  space_id,
  coalesce(signed_date, updated_at),
  product_id,
  status,
  expires_at,
  case when status in ('in_grace_period', 'in_billing_retry') then expires_at end,
  notification_uuid,
  signed_date,
  updated_at
from public.entitlements
where original_transaction_id is not null
order by environment, original_transaction_id, signed_date desc nulls last, updated_at desc
on conflict (environment, original_transaction_id) do nothing;

drop view if exists analytics.entitlement_status;
drop function if exists public.entitlement_apply(
  uuid, text, text, text, timestamptz, text, text, timestamptz, text
);
drop table if exists public.entitlements;

create or replace view public.space_entitlements
with (security_invoker = true) as
select distinct on (space_id, environment)
  space_id,
  environment,
  status,
  product_id,
  entitlement_expires_at as expires_at,
  offer_type,
  auto_renew,
  original_transaction_id,
  updated_at
from public.subscriptions
where space_id is not null
order by
  space_id,
  environment,
  case status
    when 'active' then 0
    when 'in_grace_period' then 1
    when 'in_billing_retry' then 2
    else 3
  end,
  entitlement_expires_at desc nulls last,
  signed_date desc nulls last;

revoke all on public.space_entitlements from anon, authenticated;
grant select on public.space_entitlements to service_role;

create view analytics.entitlement_status
with (security_invoker = true) as
select
  environment,
  status,
  count(*) as spaces,
  count(*) filter (where expires_at is null or expires_at > now()) as unexpired,
  max(updated_at) as last_change
from public.space_entitlements
group by environment, status
order by environment, status;

revoke all on all tables in schema analytics from anon, authenticated;
grant select on all tables in schema analytics to service_role;

create or replace function public.subscription_apply(
  p_environment text,
  p_original_transaction_id text,
  p_kind text,
  p_space_id uuid,
  p_transaction_id text,
  p_product_id text,
  p_status text,
  p_expires_at timestamptz,
  p_revoked_at timestamptz,
  p_offer_type smallint,
  p_renewal_known boolean,
  p_auto_renew boolean,
  p_grace_period_expires_at timestamptz,
  p_signed_date timestamptz,
  p_notification_uuid text,
  p_checked boolean
) returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_row public.subscriptions%rowtype;
  v_linked boolean := false;
begin
  if p_kind not in ('state', 'revocation', 'reversal') then
    raise exception 'unknown subscription event kind %', p_kind;
  end if;

  insert into public.subscriptions (
    environment,
    original_transaction_id,
    space_id,
    space_linked_at,
    product_id,
    status,
    expires_at,
    grace_period_expires_at,
    auto_renew,
    offer_type,
    latest_transaction_id,
    revoked_at,
    last_notification_uuid,
    signed_date,
    checked_at
  )
  values (
    p_environment,
    p_original_transaction_id,
    p_space_id,
    case when p_space_id is not null then coalesce(p_signed_date, now()) end,
    p_product_id,
    p_status,
    p_expires_at,
    case when p_renewal_known then p_grace_period_expires_at end,
    case when p_renewal_known then p_auto_renew end,
    p_offer_type,
    p_transaction_id,
    p_revoked_at,
    p_notification_uuid,
    p_signed_date,
    case when p_checked then now() end
  )
  on conflict (environment, original_transaction_id) do nothing;

  if found then
    return 'applied';
  end if;

  select * into v_row
  from public.subscriptions
  where environment = p_environment and original_transaction_id = p_original_transaction_id
  for update;

  if p_space_id is not null and v_row.space_id is distinct from p_space_id and (
    v_row.space_id is null
    or (
      p_signed_date is not null
      and (v_row.space_linked_at is null or p_signed_date > v_row.space_linked_at)
    )
  ) then
    update public.subscriptions
    set space_id = p_space_id, space_linked_at = coalesce(p_signed_date, now()), updated_at = now()
    where environment = p_environment and original_transaction_id = p_original_transaction_id;
    v_linked := true;
  end if;

  if p_notification_uuid is not null and v_row.last_notification_uuid = p_notification_uuid then
    return case when v_linked then 'linked' else 'duplicate' end;
  end if;

  if v_row.signed_date is not null and p_signed_date is not null
    and p_signed_date < v_row.signed_date then
    return case when v_linked then 'linked' else 'stale' end;
  end if;

  if p_kind in ('revocation', 'reversal') and not (
    v_row.latest_transaction_id is not distinct from p_transaction_id
    or v_row.expires_at is null
    or p_expires_at is null
    or p_expires_at >= v_row.expires_at
  ) then
    return case when v_linked then 'linked' else 'not_latest' end;
  end if;

  update public.subscriptions
  set
    product_id = coalesce(p_product_id, product_id),
    status = p_status,
    expires_at = p_expires_at,
    grace_period_expires_at = case
      when p_renewal_known then p_grace_period_expires_at
      else grace_period_expires_at
    end,
    auto_renew = case when p_renewal_known then p_auto_renew else auto_renew end,
    offer_type = p_offer_type,
    latest_transaction_id = coalesce(p_transaction_id, latest_transaction_id),
    revoked_at = p_revoked_at,
    last_notification_uuid = coalesce(p_notification_uuid, last_notification_uuid),
    signed_date = coalesce(p_signed_date, signed_date),
    checked_at = case when p_checked then now() else checked_at end,
    updated_at = now()
  where environment = p_environment and original_transaction_id = p_original_transaction_id;

  return 'applied';
end;
$$;

create or replace function public.subscription_link_space(
  p_environment text,
  p_original_transaction_id text,
  p_space_id uuid
) returns boolean
language sql
set search_path = public, pg_temp
as $$
  with linked as (
    update public.subscriptions
    set space_id = p_space_id, space_linked_at = now(), updated_at = now()
    where environment = p_environment and original_transaction_id = p_original_transaction_id
    returning 1
  )
  select exists (select 1 from linked);
$$;

create or replace function public.space_entitlement(p_space_id uuid, p_environment text)
returns table (
  space_id uuid,
  environment text,
  status text,
  product_id text,
  expires_at timestamptz,
  updated_at timestamptz
)
language sql
stable
set search_path = public, pg_temp
as $$
  select space_id, environment, status, product_id, expires_at, updated_at
  from public.space_entitlements
  where space_id = p_space_id and environment = p_environment;
$$;

create or replace function public.subscriptions_due_for_check(p_limit int)
returns table (environment text, original_transaction_id text)
language sql
stable
set search_path = public, pg_temp
as $$
  select environment, original_transaction_id
  from public.subscriptions
  where status in ('active', 'in_grace_period', 'in_billing_retry')
    and (
      status = 'in_billing_retry'
      or checked_at is null
      or checked_at < now() - interval '1 day'
      or entitlement_expires_at < now()
    )
  order by checked_at nulls first, updated_at
  limit p_limit;
$$;

revoke all on function public.subscription_apply(
  text, text, text, uuid, text, text, text, timestamptz, timestamptz, smallint, boolean, boolean,
  timestamptz, timestamptz, text, boolean
) from public, anon, authenticated;
grant execute on function public.subscription_apply(
  text, text, text, uuid, text, text, text, timestamptz, timestamptz, smallint, boolean, boolean,
  timestamptz, timestamptz, text, boolean
) to service_role;

revoke all on function public.subscription_link_space(text, text, uuid)
  from public, anon, authenticated;
grant execute on function public.subscription_link_space(text, text, uuid) to service_role;

revoke all on function public.space_entitlement(uuid, text) from public, anon, authenticated;
grant execute on function public.space_entitlement(uuid, text) to service_role;

revoke all on function public.subscriptions_due_for_check(int) from public, anon, authenticated;
grant execute on function public.subscriptions_due_for_check(int) to service_role;
