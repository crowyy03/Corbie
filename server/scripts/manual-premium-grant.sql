with wanted as (
  select upper(trim('XXXXXX')) as code
),
invited as (
  select i.space_id
  from public.invites i
  join wanted w on w.code = i.code
  where exists (
    select 1
    from public.invites joined
    where joined.space_id = i.space_id and joined.redeemed_at is not null
  )
)
insert into public.subscriptions (
  environment,
  original_transaction_id,
  space_id,
  space_linked_at,
  product_id,
  status,
  expires_at,
  updated_at
)
select
  'Production',
  'manual_grant:' || invited.space_id::text,
  invited.space_id,
  now(),
  'manual_grant',
  'active',
  timestamptz '2099-12-31 12:00:00+00',
  now()
from invited
on conflict (environment, original_transaction_id) do update set
  space_id = excluded.space_id,
  status = 'active',
  expires_at = excluded.expires_at,
  revoked_at = null,
  updated_at = now()
returning environment, original_transaction_id, space_id, product_id, status, expires_at;
