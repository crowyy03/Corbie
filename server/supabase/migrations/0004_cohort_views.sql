create or replace view analytics.first_open_cohort as
select anon_id, date_trunc('week', min(ts))::date as cohort_week
from public.events
where name = 'app_open'
group by anon_id;

create or replace view analytics.onboarding_funnel as
with steps as (
  select 1 as step_order, 'app_open' as step, anon_id from public.events where name = 'app_open'
  union all
  select 2, 'onboarding_step', anon_id from public.events where name = 'onboarding_step'
  union all
  select 3, 'space_created', anon_id from public.events where name = 'space_created'
  union all
  select 4, 'invite_created', anon_id from public.events where name = 'invite_created'
  union all
  select 5, 'invite_redeemed', anon_id from public.events where name = 'invite_redeemed'
)
select
  cohort.cohort_week,
  steps.step_order,
  steps.step,
  count(distinct steps.anon_id) as devices
from steps
join analytics.first_open_cohort as cohort on cohort.anon_id = steps.anon_id
group by 1, 2, 3
order by 1, 2;

create or replace view analytics.paired_ratio as
with weekly as (
  select
    cohort.cohort_week,
    count(distinct events.anon_id) filter (where events.name = 'space_created') as spaces_created,
    count(distinct events.anon_id) filter (where events.name = 'invite_created') as invites_created,
    count(distinct events.anon_id) filter (where events.name = 'invite_redeemed') as invites_redeemed
  from public.events
  join analytics.first_open_cohort as cohort on cohort.anon_id = events.anon_id
  where events.name in ('space_created', 'invite_created', 'invite_redeemed')
  group by 1
)
select
  cohort_week,
  spaces_created,
  invites_created,
  invites_redeemed,
  case when spaces_created > 0
    then round(invites_redeemed::numeric / spaces_created, 4)
  end as paired_ratio
from weekly
order by cohort_week;

revoke all on all tables in schema analytics from anon, authenticated;
grant select on all tables in schema analytics to service_role;
