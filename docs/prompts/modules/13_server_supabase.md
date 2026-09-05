# Module 13 — Server (Supabase): invites, parse, fx, entitlement, events

Read architecture §5, §6, §9, §13, §14.

## Do
1. `server/supabase/migrations/0001_init.sql`: tables `invites`, `entitlements`, `events` (monthly partitions or simple table + cron cleanup 30d), `fx_rates`. RLS on; no anon access.
2. Shared `_lib/`: `appleAuth.ts` (verify Apple identity token against Apple JWKS, check `aud` = `app.corbie`), `rateLimit.ts` (per-IP token bucket in Postgres or KV), `respond.ts`.
3. Functions (Deno/TS):
   - `invite` POST: auth required; body {spaceId, shareURL}; generate 6-char code (alphabet without ambiguous chars), TTL 15 min, invalidate previous for space.
   - `invite-redeem` GET `/:code`: return shareURL if valid and unredeemed; mark redeemed.
   - `parse` POST {url}: fetch with browser-like UA, 8s timeout, extract OG + JSON-LD Product; adapters: amazon, target, etsy, sephora, nordstrom, zara, ikea; instagram/tiktok via oEmbed (thumbnail, author) → `source`. Cache 24h by URL hash. Never return HTML.
   - `fx` GET `?base=USD`: fetch ECB via Frankfurter, cache 12h.
   - `appstore-notifications` POST: verify JWS (Apple root certs), decode payload, map `appAccountToken` → space_id, upsert entitlement (status, expires_at, product_id, original_transaction_id). Separate sandbox/prod endpoints via env.
   - `entitlement` GET `/:spaceId`: auth required; return status/expires.
   - `events` POST: batch insert; validate schema; drop PII fields defensively.
   - `apple-revoke` POST: revoke Sign in with Apple token (Apple REST) for account deletion.
4. `APIClient` (CorbieCore/Services) Swift client with typed endpoints, retries with backoff, Apple identity token header.
5. GitHub Action: `supabase db push` + `supabase functions deploy` on main.
6. Minimal SQL views for analytics: onboarding funnel, paired ratio, D1/D7/D30 by cohort, trial→paid.

## Verify
Local `supabase start`; curl each function; unit tests for parse adapters with fixture HTML; end-to-end invite flow from two devices.
