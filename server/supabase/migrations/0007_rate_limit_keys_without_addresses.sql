delete from public.rate_limits
where key !~ '^[a-z-]+:(ip|anon):[0-9a-f]{32}$'
  and key !~ '^[a-z-]+:unknown$';
