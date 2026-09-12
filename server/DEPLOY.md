# Deploying the Corbie server to Supabase

Written for someone who has never used Supabase. Every command in here was rehearsed against the local
stack on 2026-09-12: the five migrations applied, all nine functions served, and `scripts/smoke.sh`
returned 15 pass, 0 fail, 2 pending (the two that need Apple).

Two things only you can do, because they need your account and your password: creating the project
(step 1) and logging the CLI in (step 2a). Everything after that I can run for you.

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
   - **Region**: **East US (North Virginia)**. That is `us-east-1`, the lowest median latency to the
     US as a whole, and the region every Supabase default is tuned for. Pick it even though you are
     not in the US: the users are.
   - **Plan**: Free is enough to finish this checklist. Move to Pro ($25/month) before the app ships:
     free projects are paused after 7 days without traffic, and a paused project answers nothing.
4. Press **Create new project** and wait about two minutes while it provisions.

### What to copy out, and where each value goes

| Value | Where to find it | Where it goes |
| --- | --- | --- |
| **Reference ID** (looks like `abcdefghijklmnopqrst`) | Project Settings, General | This is the only value the app needs. It goes into `CORBIE_SERVER_URL` in `project.yml` (step 5), and into every command below as `<ref>`. |
| **Project URL** (`https://<ref>.supabase.co`) | Project Settings, API | Nothing to set by hand. Edge functions receive it as `SUPABASE_URL` automatically. Useful for curl. |
| **anon / publishable key** | Project Settings, API (newer dashboards: API Keys) | Nowhere. Corbie never sends it. Every function is deployed with `verify_jwt = false` and does its own auth, so the Supabase gateway asks for no key at all. |
| **service_role / secret key** | Same page, hidden behind **Reveal** | Nowhere by hand. Functions receive it as `SUPABASE_SERVICE_ROLE_KEY` automatically. It bypasses row level security: it must never reach the app bundle, the repo, or a chat. Copy it only if you want to run admin queries yourself. |

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

### 2b. Link this repo to the project (you, it asks for the database password)

```bash
cd ~/Desktop/codding/Corbie/server
supabase link --project-ref <ref>
```

It prompts for the database password from step 1. Success: `Finished supabase link.` It writes
`supabase/.temp/project-ref`, which is gitignored.

## 3. Apply the migrations

```bash
cd ~/Desktop/codding/Corbie/server
supabase db push
```

It lists the five migrations it is about to apply and asks for confirmation.

Success output ends with:

```
Applying migration 0001_init.sql...
Applying migration 0002_views.sql...
Applying migration 0003_entitlement_ordering.sql...
Applying migration 0004_cohort_views.sql...
Applying migration 0005_entitlement_statuses.sql...
Finished supabase db push.
```

Verify:

```bash
supabase migration list --linked
```

Every row must show the same version in the Local and Remote columns. A row with a Local version and
an empty Remote column means that migration did not apply.

What you should have afterwards, checked in the dashboard SQL editor:

```sql
select tablename from pg_tables where schemaname = 'public' order by 1;
-- entitlements, events, fx_rates, invites, parse_cache, rate_limits

select table_name from information_schema.views where table_schema = 'analytics' order by 1;
-- first_open_cohort, onboarding_funnel, paired_ratio, retention_d1_d7_d30, trial_to_paid

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
supabase functions deploy
```

With no function named, it deploys all nine: `session`, `invite`, `invite-redeem`, `parse`, `fx`,
`events`, `entitlement`, `apple-revoke`, `appstore-notifications`. It reads `verify_jwt = false` per
function from `supabase/config.toml`, which is what makes the gateway let unauthenticated requests
reach our own checks.

Success: a line per function ending in `Deployed Functions on project <ref>`.

Verify:

```bash
supabase functions list
```

Nine rows, each with status `ACTIVE` and `verify_jwt` false.

## 5. Secrets

Dashboard, Project Settings, Edge Functions, Secrets, **Add new secret**. Use the dashboard rather
than `supabase secrets set` for the private key: the CLI form puts the value in your shell history.

| Secret | What it is for | Where the value comes from | Blocked? |
| --- | --- | --- | --- |
| `SESSION_SECRET` | HMAC key that signs the 180-day Corbie session token, so the app does not have to hold a short-lived Apple token. Every protected endpoint verifies against it. | `openssl rand -base64 48`, once. Store it in your password manager; changing it signs everyone out. | ready now |
| `APPLE_CLIENT_ID` | The `aud` claim demanded of Apple identity tokens. | `app.corbie` | ready now |
| `APPLE_BUNDLE_ID` | The bundle App Store notifications must name, so another app's notifications are refused. | `app.corbie` | ready now |
| `APPLE_ENV` | Which App Store environment this project accepts. A notification from the other one is rejected. | `Sandbox` while testing, `Production` for the shipping project. Set `Sandbox` now. | ready now |
| `APPLE_TEAM_ID` | Signs the client secret used to revoke a Sign in with Apple credential on account deletion. | Apple Developer, Membership details, Team ID. | **blocked on the Apple account** |
| `APPLE_KEY_ID` | Same signature, names which key signed it. | Apple Developer, Certificates Identifiers and Profiles, Keys, the key with Sign in with Apple enabled. | **blocked on the Apple account** |
| `APPLE_PRIVATE_KEY` | Same signature, the key itself. | The `.p8` file Apple lets you download exactly once when you create that key. Paste the whole file including the BEGIN and END lines; real newlines and `\n` escapes both work. | **blocked on the Apple account** |
| `INSTAGRAM_OEMBED_TOKEN` | Lets the wish parser read Instagram and TikTok links through oEmbed. | A Meta app access token. Optional: without it those two sites fall back to a bare link and every other shop still parses. | optional, leave empty |

Do not set these four, they are injected into every function automatically and the CLI refuses names
that start with `SUPABASE_`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`,
`SUPABASE_DB_URL`. The smoke test proves they arrived: if `/fx` answers 200, the function reached the
database with the service role key.

What the three blocked secrets cost you until the Apple account exists: `POST /apple-revoke` answers
`500 Server is missing APPLE_TEAM_ID`, so deleting an account removes the data but leaves the Apple
credential granted. Nothing else degrades.

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
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17' build
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

| Check | Proves |
| --- | --- |
| `GET /fx?base=USD` | The function runs, reached Postgres with the injected service role key, and called the upstream rate feed. |
| `GET /fx?base=XX` | Input validation and the shared error shape. |
| `POST /parse` | Outbound fetching, the shop adapters and the parse cache. |
| `POST /events` | The analytics allowlist and the insert path. |
| `GET /invite-redeem/ZZZZZZ` | Unknown codes are a clean 404, not a crash. |
| `GET /entitlement/{id}` without a token | Auth is enforced inside the function, so `verify_jwt = false` did not open a hole. |
| `OPTIONS /fx` | No CORS surface: browsers get 405. |
| `POST /invite` with a session token | Session tokens work end to end, and a code is written to the database. |
| `GET /invite-redeem/{code}` twice | The pairing flow: first call returns the share link, second is 410 redeemed. |
| `GET /entitlement/{id}` with a token | An unknown space answers `status: none` rather than failing. |
| `POST /session` with a session token | A session token cannot mint another session token. |

## What is live after this, and what is not

Working end to end once steps 1 to 7 are done: invite codes, link parsing for wishes, currency rates,
anonymous analytics with its four views, entitlement reads, the per-IP rate limiter, and the nightly
purge.

Still blocked, all on the Apple Developer account: `POST /session` (needs a real identity token),
`POST /apple-revoke` (needs the `.p8`), and App Store Server Notifications, which are what write
entitlement rows in the first place. Until then every paying state comes from the local StoreKit
transaction on the device, which is what the app already falls back to. When the account exists, set
the three Apple secrets, put
`https://<ref>.supabase.co/functions/v1/appstore-notifications` into App Store Connect as the
notification URL for both Sandbox and Production, and flip `APPLE_ENV` on the production project.
