with wanted as (
  select upper(trim('XXXXXX')) as code
)
select
  i.code,
  i.space_id,
  i.created_at,
  i.expires_at,
  i.redeemed_at,
  i.superseded_at,
  i.cloudkit_environment,
  exists (
    select 1
    from public.invites joined
    where joined.space_id = i.space_id and joined.redeemed_at is not null
  ) as partner_joined,
  e.status as production_status,
  e.product_id as production_product,
  e.expires_at as production_expires_at
from public.invites i
join wanted w on w.code = i.code
left join public.space_entitlements e
  on e.space_id = i.space_id and e.environment = 'Production';
