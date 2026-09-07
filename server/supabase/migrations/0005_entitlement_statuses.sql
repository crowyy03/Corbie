alter table public.entitlements
  drop constraint if exists entitlements_status_check;

update public.entitlements set status = 'in_grace_period' where status = 'grace';

alter table public.entitlements
  add constraint entitlements_status_check
  check (status in ('none', 'active', 'in_grace_period', 'in_billing_retry', 'expired', 'revoked'));

drop view if exists analytics.trial_to_paid;

create or replace view analytics.entitlement_status as
select
  status,
  count(*) as spaces,
  count(*) filter (where expires_at is null or expires_at > now()) as unexpired,
  max(updated_at) as last_notification
from public.entitlements
group by status
order by status;

revoke all on all tables in schema analytics from anon, authenticated;
grant select on all tables in schema analytics to service_role;
