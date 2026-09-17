create table if not exists public.app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;
alter table public.app_config force row level security;

revoke all on public.app_config from anon, authenticated;

insert into public.app_config (key, value) values ('monetization_enabled', 'false'::jsonb)
on conflict (key) do nothing;
