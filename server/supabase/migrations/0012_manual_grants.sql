create or replace function public.subscriptions_due_for_check(p_limit int)
returns table (environment text, original_transaction_id text)
language sql
stable
set search_path = public, pg_temp
as $$
  select environment, original_transaction_id
  from public.subscriptions
  where status in ('active', 'in_grace_period', 'in_billing_retry')
    and product_id is distinct from 'manual_grant'
    and (
      status = 'in_billing_retry'
      or checked_at is null
      or checked_at < now() - interval '1 day'
      or entitlement_expires_at < now()
    )
  order by checked_at nulls first, updated_at
  limit p_limit;
$$;
