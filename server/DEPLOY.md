# Deploying the Corbie server to Supabase

Written for someone who has never used Supabase. Every command here was run for real on 2026-09-12
against the live project `powtuiqqagdoiuqjeebr` in East US (Ohio): five migrations applied, nine
functions deployed, `scripts/smoke.sh` 15 pass, 0 fail, 2 pending (the two that need Apple).
On 2026-09-17 the live project got migrations `0006` and `0007`, all ten functions were redeployed,
`SESSION_SECRET` was rotated and `RATE_LIMIT_SALT` was added; `scripts/smoke.sh` answered 16 pass,
0 fail, 2 pending.

Two things only you can do, because they need your account: creating the project (step 1) and logging
the CLI in (step 2a). Everything after that runs from this repo.

Never paste the database password or the service role key into a chat, a commit, or a ticket.

## 1. Create the project

1. Open `https://supabase.com` and press **Start your project**. Sign in with GitHub or with an email
   address. A personal organization is created for you on first sign-in.
2. Press **New project**.
3. Fill the form:
   - **Name**: `corbie`.
   - **Database Password**: press **Generate a password**, then copy it into your password manager
     under "Corbie Supabase DB". You need it once, in step 2b. Losing it is survivable (you can reset
     it in Project Settings, Database), but resetting invalidates anything already using it.
   - **Region**: an East US one, because the users are in the US and the region cannot be changed
     later. The live project sits in **East US (Ohio)**, `us-east-2`; **East US (North Virginia)**,
     `us-east-1`, is the other sensible pick. The difference between the two is single-digit
     milliseconds, so either is fine and neither is worth redoing.
   - **Plan**: Free is enough to finish this checklist. Move to Pro ($25/month) before the app ships:
     free projects are paused after 7 days without traffic, and a paused project answers nothing.
4. Press **Create new project** and wait about two minutes while it provisions.

### What to copy out, and where each value goes

| Value                                                | Where to find it                                   | Where it goes                                                                                                                                                                                                                        |
| ---------------------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Reference ID** (looks like `abcdefghijklmnopqrst`) | Project Settings, General                          | This is the only value the app needs. It goes into `CORBIE_SERVER_URL` in `project.yml` (step 5), and into every command below as `<ref>`.                                                                                           |
| **Project URL** (`https://<ref>.supabase.co`)        | Project Settings, API                              | Nothing to set by hand. Edge functions receive it as `SUPABASE_URL` automatically. Useful for curl.                                                                                                                                  |
| **anon / publishable key**                           | Project Settings, API (newer dashboards: API Keys) | Nowhere. Corbie never sends it. Every function is deployed with `verify_jwt = false` and does its own auth, so the Supabase gateway asks for no key at all.                                                                          |
| **service_role / secret key**                        | Same page, hidden behind **Reveal**                | Nowhere by hand. Functions receive it as `SUPABASE_SERVICE_ROLE_KEY` automatically. It bypasses row level security: it must never reach the app bundle, the repo, or a chat. Copy it only if you want to run admin queries yourself. |

## 2. Point the CLI at the project

The CLI is already installed (`supabase 2.117.0`).

### 2a. Log in (you)

```bash
supabase login
```

It opens a browser, you approve, and it stores an access token in `~/.supabase`. If you would rather
not use the browser: Dashboard, Account, Access Tokens, **Generate new token**, then
`export SUPABASE_ACCESS_TOKEN=<token>` in the shell you use for the rest.

Check it worked:

```bash
supabase projects list
```

Success looks like a table with your project and its reference id. Failure is
`Access token not provided`.

### 2b. Link this repo to the project

```bash
cd ~/Desktop/codding/Corbie/server
supabase link --project-ref <ref> -p ""
```

The `-p ""` skips the database password prompt. On 2026-09-12 that was enough for everything below:
`supabase db push` printed `Initialising login role...` and provisioned its own short-lived role from
the access token, so the password was never needed. Keep it anyway, for psql and for the dashboard.

Success writes `supabase/.temp/project-ref`, which is gitignored.

## 3. Apply the migrations

```bash
cd ~/Desktop/codding/Corbie/server
supabase db push
```

It lists the migrations the project does not have yet (all nine on a new project) and asks for confirmation. Add `< /dev/null` to
take the default. Dry run first with `supabase db push --dry-run` if you want to see the list without
applying anything.

Success output ends with:

```
Applying migration 0001_init.sql...
Applying migration 0002_views.sql...
Applying migration 0003_entitlement_ordering.sql...
Applying migration 0004_cohort_views.sql...
Applying migration 0005_entitlement_statuses.sql...
Applying migration 0006_app_config.sql...
Applying migration 0007_rate_limit_keys_without_addresses.sql...
Applying migration 0008_invite_supersede_and_redeemer.sql...
Applying migration 0009_subscriptions.sql...
Finished supabase db push.
```

Verify:

```bash
supabase migration list --linked
supabase inspect db table-stats --linked
```

Every migration row must show the same version in the Local and Remote columns, and the table list
must hold `app_config`, `invites`, `subscriptions`, `events`, `fx_rates`, `parse_cache` and
`rate_limits`. A row with a Local version and an empty Remote column means that migration did not
apply.

What you should have afterwards, checked in the dashboard SQL editor:

```sql
select tablename from pg_tables where schemaname = 'public' order by 1;
-- app_config, events, fx_rates, invites, parse_cache, rate_limits, subscriptions

select key, value from public.app_config;
-- monetization_enabled | false

select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'invites'
  and column_name in ('superseded_at', 'redeemed_by') order by 1;
-- redeemed_by, superseded_at

select table_name from information_schema.views where table_schema = 'analytics' order by 1;
-- entitlement_status, first_open_cohort, onboarding_funnel, paired_ratio, retention_d1_d7_d30

select table_name from information_schema.views where table_schema = 'public' order by 1;
-- space_entitlements

select jobname, schedule from cron.job;
-- corbie_purge_expired_rows | 17 3 * * *
```

The last one is the nightly cleanup: events older than 30 days, invites older than a day, the parse
cache older than a week. If `cron.job` does not exist, the migration said so with a notice and
carried on; the tables are still correct, only the cleanup is missing. Enable `pg_cron` under
Database, Extensions and run `supabase db push` again.

## 4. Deploy the functions

```bash
cd ~/Desktop/codding/Corbie/server
supabase functions deploy --import-map supabase/functions/deno.json
```

Without Docker running, the CLI bundles on Supabase's side, and that bundler does not read the
workspace `deno.json` by itself: every function fails with `Relative import path "@supabase/supabase-js"
not prefixed with / or ./ or ../`. `--import-map` hands it the import map; with Docker running the flag
is harmless.

Migration 0009 replaces the `entitlements` table with `subscriptions` and moves every old row
across, keeping the environment it was written under. The `appstore-notifications` and
`entitlement` functions deployed before 2026-09-25 read and write the old table, so from the moment
0009 runs until the new functions are deployed they answer `500`. Run the migration and the function
deploy back to back (the manual CI job in section 8 does exactly that); Apple retries a failed
production notification for three days, so nothing is lost in that minute.

Apply migration 0008 before deploying `invite` and `invite-redeem` from 2026-09-21 on: both read and
write `superseded_at` and `redeemed_by`, and without the columns every invite and every redeem answers
`500 internal`. The older functions keep working on the new columns, so the migration can go first
with no downtime.

With no function named, it deploys all eleven: `session`, `invite`, `invite-redeem`, `parse`, `fx`,
`config`, `events`, `entitlement`, `apple-revoke`, `appstore-notifications`,
`appstore-reconcile`. It reads
`verify_jwt = false` per function from `supabase/config.toml`, which is what makes the gateway let
unauthenticated requests reach our own checks.

Success: a line per function ending in `Deployed Functions on project <ref>`.

Verify:

```bash
supabase functions list
```

Eleven rows, each with status `ACTIVE` and `verify_jwt` false.

## 5. Secrets

Dashboard, Project Settings, Edge Functions, Secrets, **Add new secret**. Use the dashboard rather
than `supabase secrets set` for the private key: the CLI form puts the value in your shell history.

| Secret                   | What it is for                                                                                                                                                                                                                               | Where the value comes from                                                                                                                                                                                                                 | Blocked?              |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------- |
| `SESSION_SECRET`         | HMAC key that signs the 180-day Corbie session token, so the app does not have to hold a short-lived Apple token. Every protected endpoint verifies against it.                                                                              | `openssl rand -base64 48`. Rotated on 2026-09-17 because the earlier local copy was lost; the value lives only in your password manager. Changing it signs everyone out.                                                                   | set                   |
| `RATE_LIMIT_SALT`        | HMAC key for the rate limit bucket key and for `invites.redeemed_by`, so `rate_limits` holds a digest of the caller's IP and never the address, and `invites` a digest of the device id. Without it every rate-limited endpoint answers 500. | `openssl rand -base64 48`, once, set before the functions that read it are deployed. Nobody needs to read it back; rotating it resets the buckets, and a device that redeemed a code in the fifteen minutes before cannot redeem it again. | set                   |
| `APPLE_CLIENT_ID`        | The `aud` claim demanded of Apple identity tokens.                                                                                                                                                                                           | `app.corbie`                                                                                                                                                                                                                               | set                   |
| `APPLE_BUNDLE_ID`        | The bundle App Store notifications must name, so another app's notifications are refused.                                                                                                                                                    | `app.corbie`                                                                                                                                                                                                                               | set                   |
| `APPSTORE_ISSUER_ID`     | Signs the requests to the App Store Server API (sync, reconcile, the TEST notification script).                                                                                                                                              | App Store Connect, Users and Access, Integrations, Keys, In-App Purchase: the **Issuer ID** at the top of the page.                                                                                                                        | not set yet           |
| `APPSTORE_KEY_ID`        | Names which In-App Purchase key signed the request.                                                                                                                                                                                          | Same page: press **Generate In-App Purchase Key**, name it `Corbie server`; the **Key ID** is shown next to the key. Do not reuse `APPLE_KEY_ID`, that is the Sign in with Apple key.                                                      | not set yet           |
| `APPSTORE_PRIVATE_KEY`   | The In-App Purchase key itself.                                                                                                                                                                                                              | Press **Download Key** next to the new key. Apple offers the `.p8` file once only. Paste the whole file including the BEGIN and END lines; real newlines and `\n` escapes both work. Keep a copy in your password manager.                 | not set yet           |
| `APPSTORE_APP_APPLE_ID`  | The app id a Production notification must name, so another app's notifications are dropped.                                                                                                                                                  | `6812410537`: App Store Connect, the app, App Information, **Apple ID**. Not a secret, and the code falls back to the same value when it is unset.                                                                                         | optional              |
| `APPLE_TEAM_ID`          | Signs the client secret used to revoke a Sign in with Apple credential on account deletion.                                                                                                                                                  | Apple Developer, Membership details, Team ID.                                                                                                                                                                                              | set                   |
| `APPLE_KEY_ID`           | Same signature, names which key signed it.                                                                                                                                                                                                   | Apple Developer, Certificates Identifiers and Profiles, Keys, the key with Sign in with Apple enabled.                                                                                                                                     | set                   |
| `APPLE_PRIVATE_KEY`      | Same signature, the key itself.                                                                                                                                                                                                              | The `.p8` file Apple lets you download exactly once when you create that key. Paste the whole file including the BEGIN and END lines; real newlines and `\n` escapes both work.                                                            | set                   |
| `INSTAGRAM_OEMBED_TOKEN` | Lets the wish parser read Instagram and TikTok links through oEmbed.                                                                                                                                                                         | A Meta app access token. Optional: without it those two sites fall back to a bare link and every other shop still parses.                                                                                                                  | optional, leave empty |

Do not set these four, they are injected into every function automatically and the CLI refuses names
that start with `SUPABASE_`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`,
`SUPABASE_DB_URL`. The smoke test proves they arrived: if `/fx` answers 200, the function reached the
database with the service role key.

The three Apple key secrets are set. Checked on 2026-09-22 with the smoke test: `POST /apple-revoke`
with the smoke test's fake authorization code answers `502 Apple did not accept the authorization code`,
so the function reads the key, signs the client secret and reaches Apple. Before the key was set again
it answered `500` because the key could not be read. Only a real account deletion on a device can
produce the `204`.

What the secrets cost when they are missing: `POST /apple-revoke` answers
`500 Server is missing APPLE_TEAM_ID`, so deleting an account removes the data but leaves the Apple
credential granted. Without the three `APPSTORE_*` key secrets, `POST /entitlement/sync` still stores
the purchase from the signed transaction the app sends and answers `reconciled: false`, and
`appstore-reconcile` answers `configured: false` and does nothing; notifications keep working, they
need no key. Nothing else degrades.

`APPLE_ENV` is no longer read by anything: the environment comes from the signed payload itself.
Delete it from the dashboard once the functions from 2026-09-25 are deployed. Before that the old
`appstore-notifications` still reads it, and deleting it early makes that old function refuse the
sandbox notifications it accepts today.

## 6. Point the app at the live project

In `project.yml`, base settings:

```diff
-    CORBIE_SERVER_URL: ""
+    CORBIE_SERVER_URL: "<ref>"
```

Then regenerate and build:

```bash
cd ~/Desktop/codding/Corbie
xcodegen generate
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Main' build
```

The setting reaches the app and the share extension through their Info plists, and
`ServerConfiguration.fromBundle` turns a bare reference id into
`https://<ref>.supabase.co/functions/v1`. A full `https://` URL works too, for a custom domain later.
Empty means the placeholder host, which is what ships today.

## 7. Smoke test

```bash
cd ~/Desktop/codding/Corbie/server
SESSION_SECRET='<the same value you put in the dashboard>' \
  deno run --quiet --allow-env --config deno.json scripts/session-token.ts > /tmp/corbie-token
bash scripts/smoke.sh "https://<ref>.supabase.co/functions/v1" "$(cat /tmp/corbie-token)"
rm /tmp/corbie-token
```

It prints a table and exits non-zero if anything failed.

### How to get a token for the endpoints that need one

`invite`, `entitlement` and `apple-revoke` accept either an Apple identity token or a Corbie session
token, and the session token is just an HS256 JWT signed with `SESSION_SECRET`, which you own. So
`scripts/session-token.ts` mints one locally through the server's own code, no Apple involved. That
is the whole trick: those three endpoints are fully testable today.

`POST /session` is the exception by design. It refuses session tokens and demands a real Apple
identity token, so it can only be exercised by the app on a physical device signed into an Apple ID,
with the app signed by a team that has Sign in with Apple. That needs the Apple account, so it stays
pending. The simulator cannot do it either: it has no iCloud account.

### What each check proves

| Check                                                                       | Proves                                                                                                     |
| --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `GET /fx?base=USD`                                                          | The function runs, reached Postgres with the injected service role key, and called the upstream rate feed. |
| `GET /fx?base=XX`                                                           | Input validation and the shared error shape.                                                               |
| `GET /config`                                                               | The monetization flag is readable without auth and `app_config` exists.                                    |
| `POST /parse`                                                               | Outbound fetching, the shop adapters and the parse cache.                                                  |
| `POST /events`                                                              | The analytics allowlist and the insert path.                                                               |
| `GET /invite-redeem/ZZZZZZ`                                                 | Unknown codes are a clean 404, not a crash.                                                                |
| `GET /entitlement/{id}` without a token                                     | Auth is enforced inside the function, so `verify_jwt = false` did not open a hole.                         |
| `POST /appstore-reconcile` without a key                                    | Reconciliation is deployed and refuses anyone without the service role key.                                |
| `OPTIONS /fx`                                                               | No CORS surface: browsers get 405.                                                                         |
| `POST /invite` with a session token                                         | Session tokens work end to end, and a code is written to the database.                                     |
| `POST /invite` twice for one space                                          | The second code supersedes the first.                                                                      |
| `GET /invite-redeem/{first code}`                                           | A replaced code answers 410 superseded, not expired.                                                       |
| `GET /invite-redeem/{second code}` from one device, twice                   | The pairing flow, and a retry from the same device gets the same share link again.                         |
| `GET /invite-redeem/{second code}` from another device or with no device id | 409 redeemed.                                                                                              |
| `GET /entitlement/{id}` with a token                                        | An unknown space answers `status: none` in `Production` rather than failing.                               |
| `POST /entitlement/sync` with an unsigned transaction                       | Sync is deployed and refuses anything Apple did not sign.                                                  |
| `POST /session` with a session token                                        | A session token cannot mint another session token.                                                         |

## Turning monetization on

The flag is one row in `app_config`. Migration 0006 creates it as `false`, and `GET /config`
returns whatever the row holds, read fresh on every request. From 2026-09-25 a missing row counts as
on, because v1 is paid from day one, and so does an app that never managed to fetch the flag. Update
the row, never delete it: deleting it turns monetization on for everyone at once.

To turn it on: Dashboard, SQL Editor, **New query**, paste and press **Run**:

```sql
update public.app_config set value = 'true'::jsonb, updated_at = now() where key = 'monetization_enabled';
```

Check the row in the same editor:

```sql
select key, value, updated_at from public.app_config;
```

It must show `monetization_enabled`, `true`, and an `updated_at` from a moment ago. No row at all
means migration 0006 never ran: go back to step 3.

Then check what the app will see:

```bash
curl -s "https://<ref>.supabase.co/functions/v1/config"
```

It must print `{"monetizationEnabled":true}`.

To turn it off again, the same way:

```sql
update public.app_config set value = 'false'::jsonb, updated_at = now() where key = 'monetization_enabled';
```

and the same `select` must show `false`, and the same curl must print
`{"monetizationEnabled":false}`.

Only ever write `'true'::jsonb` or `'false'::jsonb`. Anything else, the string `'"true"'` or
`'null'` included, makes the endpoint answer `500` with `"error":"internal"` instead of a value, on
purpose: a broken value must never read as `false`.

## 8. Migrations and deploys from CI are manual

`.github/workflows/supabase.yml` runs `deno fmt --check`, `deno lint`, `deno check` and the tests on
every push and pull request that touches `server/`. It never touches the live project on its own.
Migrations and function deploys run only when you start them:

1. GitHub, the repository, **Actions**, **Supabase** in the list on the left.
2. **Run workflow**, branch `main`, and type `deploy` into **Type deploy to push migrations and
   functions to the production project**. Anything else, or any other branch, runs only the tests.
3. The job runs the tests first, then `supabase db push` and `supabase functions deploy`.

It needs the repository secrets `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF` and
`SUPABASE_DB_PASSWORD` and the `production` environment. On 2026-09-25 `SUPABASE_ACCESS_TOKEN` was
not set, so today CI deploys nothing and the job fails with a message saying so; until you add it,
deploy by hand with steps 3 and 4.

## 9. App Store Server Notifications

One URL takes both environments:

```
https://<ref>.supabase.co/functions/v1/appstore-notifications
```

App Store Connect, the app, App Information, **App Store Server Notifications**: set it as the
**Production Server URL** and as the **Sandbox Server URL**, Version 2 for both. The function reads
the environment from the signed payload and keeps Sandbox and Production subscriptions apart; a
TestFlight purchase is Sandbox.

To prove the path end to end once the three `APPSTORE_*` key secrets exist, ask Apple for a `TEST`
notification in each environment:

```bash
cd ~/Desktop/codding/Corbie/server
export APPSTORE_ISSUER_ID='<issuer id>' APPSTORE_KEY_ID='<key id>'
export APPSTORE_PRIVATE_KEY="$(cat ~/Downloads/SubscriptionKey_<key id>.p8)"
deno run --allow-env --allow-net --config deno.json scripts/request-test-notification.ts Sandbox
deno run --allow-env --allow-net --config deno.json scripts/request-test-notification.ts Production
```

Each prints the send attempts Apple recorded and exits `0` on `SUCCESS`. The function answers a
`TEST` notification `200` and logs `notification ignored: TEST changes nothing`, which is the
function log line to look for under Edge Functions, `appstore-notifications`, Logs.

## 10. Daily reconciliation

`appstore-reconcile` re-reads from Apple every subscription whose state could be stale and replays
the notifications Apple failed to deliver in the last three days. It answers only the service role
key. By hand:

```bash
curl -s -X POST "https://<ref>.supabase.co/functions/v1/appstore-reconcile" \
  -H "authorization: Bearer <service role key>" -H "content-type: application/json" -d '{}'
```

`{"days": 30}` in the body replays a longer window (at most 179 days in Production, 29 in Sandbox).
Use the key the functions see as `SUPABASE_SERVICE_ROLE_KEY`: the `service_role` key under Project
Settings, API Keys (on the Legacy tab if the dashboard shows both kinds). A `401` means it was a
different key.

The repo does not enable `pg_net`, so the daily run is not scheduled by any migration. To schedule
it, run this once in the SQL Editor, with the project ref and the service role key filled in:

```sql
create extension if not exists pg_net with schema extensions;
select vault.create_secret('https://<ref>.supabase.co', 'corbie_project_url');
select vault.create_secret('<service role key>', 'corbie_service_role_key');
select cron.schedule('corbie_appstore_reconcile', '41 4 * * *', $$ select net.http_post(url := (select decrypted_secret from vault.decrypted_secrets where name = 'corbie_project_url') || '/functions/v1/appstore-reconcile', headers := jsonb_build_object('content-type', 'application/json', 'authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'corbie_service_role_key')), body := '{}'::jsonb, timeout_milliseconds := 150000); $$);
```

The key stays in Vault, encrypted, and never appears in the job text. Check with
`select jobname, schedule from cron.job;`, which must list `corbie_appstore_reconcile` next to
`corbie_purge_expired_rows`, and after the first night with
`select status_code, content from net._http_response order by created desc limit 1;`.

## What is live after this, and what is not

Working end to end once steps 1 to 7 are done: invite codes, link parsing for wishes, currency rates,
the monetization flag, anonymous analytics with its views, entitlement reads, the per-IP rate
limiter, and the nightly purge.

`POST /session` and `POST /apple-revoke` have their Apple secrets (section 5); they are exercised end
to end only by a real sign in and a real account deletion on a device. Still open on 2026-09-25:
migration 0009 and the functions from that day are not deployed, the three `APPSTORE_*` key secrets
do not exist, the notification URLs point at the old function (section 9), no real Apple
notification has reached the endpoint yet, and the daily reconciliation is not scheduled (section
10). Until notifications arrive, every paying state comes from the local StoreKit transaction on the
device that bought it.
