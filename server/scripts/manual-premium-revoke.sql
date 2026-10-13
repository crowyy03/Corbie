update public.subscriptions
set status = 'revoked', revoked_at = now(), expires_at = now(), updated_at = now()
where environment = 'Production'
  and product_id = 'manual_grant'
  and original_transaction_id = 'manual_grant:' || lower(trim('00000000-0000-0000-0000-000000000000'))
  and status = 'active'
returning environment, original_transaction_id, space_id, status, revoked_at;
