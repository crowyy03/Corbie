select space_id, status, expires_at, revoked_at, space_linked_at, updated_at
from public.subscriptions
where environment = 'Production' and product_id = 'manual_grant'
order by space_linked_at;
