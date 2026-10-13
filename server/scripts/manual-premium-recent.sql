select
  i.code,
  i.space_id,
  i.created_at,
  i.redeemed_at,
  i.cloudkit_environment,
  e.status as production_status
from public.invites i
left join public.space_entitlements e
  on e.space_id = i.space_id and e.environment = 'Production'
where i.created_at > now() - interval '24 hours'
  and i.redeemed_at is not null
order by i.redeemed_at desc;
