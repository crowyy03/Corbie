create schema if not exists analytics;

revoke all on schema analytics from anon, authenticated;
grant usage on schema analytics to service_role;

create or replace view analytics.onboarding_funnel as
with steps as (
  select 1 as step_order, 'app_open' as step, anon_id, ts from public.events where name = 'app_open'
  union all
  select 2, 'onboarding_step', anon_id, ts from public.events where name = 'onboarding_step'
  union all
  select 3, 'space_created', anon_id, ts from public.events where name = 'space_created'
  union all
  select 4, 'invite_created', anon_id, ts from public.events where name = 'invite_created'
  union all
  select 5, 'invite_redeemed', anon_id, ts from public.events where name = 'invite_redeemed'
)
select
  date_trunc('week', ts)::date as cohort_week,
  step_order,
  step,
  count(distinct anon_id) as devices
from steps
group by 1, 2, 3
order by 1, 2;

create or replace view analytics.paired_ratio as
with weekly as (
  select
    date_trunc('week', ts)::date as cohort_week,
    count(distinct anon_id) filter (where name = 'space_created') as spaces_created,
    count(distinct anon_id) filter (where name = 'invite_created') as invites_created,
    count(distinct anon_id) filter (where name = 'invite_redeemed') as invites_redeemed
  from public.events
  where name in ('space_created', 'invite_created', 'invite_redeemed')
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

create or replace view analytics.retention_d1_d7_d30 as
with first_open as (
  select anon_id, min(ts) as first_ts
  from public.events
  where name = 'app_open'
  group by anon_id
),
cohorts as (
  select anon_id, first_ts, date_trunc('week', first_ts)::date as cohort_week
  from first_open
),
returns as (
  select
    cohorts.cohort_week,
    cohorts.anon_id,
    floor(extract(epoch from (events.ts - cohorts.first_ts)) / 86400)::int as day_offset
  from cohorts
  join public.events on events.anon_id = cohorts.anon_id and events.name = 'app_open'
)
select
  cohort_week,
  count(distinct anon_id) as cohort_size,
  count(distinct anon_id) filter (where day_offset between 1 and 1) as returned_d1,
  count(distinct anon_id) filter (where day_offset between 7 and 7) as returned_d7,
  count(distinct anon_id) filter (where day_offset between 30 and 30) as returned_d30
from returns
group by cohort_week
order by cohort_week;

create or replace view analytics.trial_to_paid as
with trials as (
  select anon_id, min(ts) as trial_ts
  from public.events
  where name = 'trial_started'
  group by anon_id
),
purchases as (
  select anon_id, min(ts) as purchase_ts
  from public.events
  where name = 'purchase'
  group by anon_id
)
select
  date_trunc('week', trials.trial_ts)::date as cohort_week,
  count(*) as trials_started,
  count(purchases.anon_id) filter (where purchases.purchase_ts >= trials.trial_ts) as converted,
  case when count(*) > 0 then round(
    count(purchases.anon_id) filter (where purchases.purchase_ts >= trials.trial_ts)::numeric / count(*),
    4
  ) end as conversion
from trials
left join purchases on purchases.anon_id = trials.anon_id
group by 1
order by 1;

revoke all on all tables in schema analytics from anon, authenticated;
grant select on all tables in schema analytics to service_role;
