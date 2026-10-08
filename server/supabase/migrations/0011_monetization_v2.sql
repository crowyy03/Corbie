insert into public.app_config (key, value) values
  ('monetization_v2_enabled', 'false'::jsonb),
  ('free_days', '3'::jsonb)
on conflict (key) do nothing;
