alter table public.entitlements add column if not exists signed_date timestamptz;
alter table public.entitlements add column if not exists notification_uuid text;

create or replace function public.entitlement_apply(
  p_space_id uuid,
  p_original_transaction_id text,
  p_product_id text,
  p_status text,
  p_expires_at timestamptz,
  p_payer_hash text,
  p_environment text,
  p_signed_date timestamptz,
  p_notification_uuid text
) returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_applied boolean;
begin
  insert into public.entitlements as current (
    space_id,
    original_transaction_id,
    product_id,
    status,
    expires_at,
    payer_hash,
    environment,
    signed_date,
    notification_uuid,
    updated_at
  )
  values (
    p_space_id,
    p_original_transaction_id,
    p_product_id,
    p_status,
    p_expires_at,
    p_payer_hash,
    p_environment,
    p_signed_date,
    p_notification_uuid,
    now()
  )
  on conflict (space_id) do update set
    original_transaction_id = excluded.original_transaction_id,
    product_id = excluded.product_id,
    status = excluded.status,
    expires_at = excluded.expires_at,
    payer_hash = excluded.payer_hash,
    environment = excluded.environment,
    signed_date = excluded.signed_date,
    notification_uuid = excluded.notification_uuid,
    updated_at = now()
  where (
    excluded.notification_uuid is null
    or current.notification_uuid is distinct from excluded.notification_uuid
  ) and (
    current.signed_date is null
    or excluded.signed_date is null
    or current.signed_date <= excluded.signed_date
  )
  returning true into v_applied;

  return coalesce(v_applied, false);
end;
$$;

revoke all on function public.entitlement_apply(
  uuid, text, text, text, timestamptz, text, text, timestamptz, text
) from public, anon, authenticated;

grant execute on function public.entitlement_apply(
  uuid, text, text, text, timestamptz, text, text, timestamptz, text
) to service_role;
