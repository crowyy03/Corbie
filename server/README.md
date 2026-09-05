# Corbie server

Supabase project behind the app: invite codes, link parsing, FX rates, entitlements, anonymous analytics. Postgres plus Deno edge functions, no other runtime.

Couple data never reaches this server. It holds invite codes with a 15 minute TTL, one entitlement row per `spaceId`, anonymous events keyed by a device UUID, and two caches.

The request and response contract is `API.md`. Architecture sections 5, 6, 9, 13 and 14 in `docs/03_TECH_ARCHITECTURE.md` are the source of truth behind it.

## Layout

```
supabase/config.toml            local stack and per function verify_jwt
supabase/migrations/0001_init   tables, RLS, rate limiter, nightly purge
supabase/migrations/0002_views  analytics schema and its four views
supabase/functions/_shared      auth, rate limit, responses, parsing, Apple crypto
supabase/functions/<name>       one Deno.serve entry point per endpoint
tests/                          deno tests and fixture HTML
```

Every function is deployed with `verify_jwt = false`. The Supabase gateway checks nothing; each function does its own check, because `invite`, `entitlement` and `apple-revoke` authenticate with an Apple identity token rather than a Supabase JWT, and `appstore-notifications` authenticates with Apple's signature over the payload.

## Local

Docker must be running.

```
cd server
supabase start
supabase functions serve
```

`supabase start` applies both migrations into the local database and prints the local URLs. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected into the local runtime, so only the Apple secrets need a `supabase/functions/.env` file locally (copy `.env.example`).

Endpoints that need no Apple token can be exercised straight away:

```
curl "http://127.0.0.1:54321/functions/v1/fx?base=USD"

curl -X POST "http://127.0.0.1:54321/functions/v1/parse" \
  -H "content-type: application/json" \
  -d '{"url":"https://www.amazon.com/dp/B000P4D5HG"}'

curl -X POST "http://127.0.0.1:54321/functions/v1/events" \
  -H "content-type: application/json" \
  -H "X-Anon-Id: 11111111-1111-4111-8111-111111111111" \
  -d '{"events":[{"name":"app_open"}]}'
```

`invite` needs a real Apple identity token, so the redeem half is easiest to try against a seeded row:

```
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2- | tr -d '"')" -c \
  "insert into invites(code, space_id, share_url, expires_at)
   values ('K7M2QX', gen_random_uuid(), 'https://www.icloud.com/share/x', now() + interval '15 minutes');"

curl "http://127.0.0.1:54321/functions/v1/invite-redeem/K7M2QX"
```

Stop with `supabase stop`. Reset the database to the migrations with `supabase db reset`.

## Tests

```
cd server
deno test -A
deno check supabase/functions/*/index.ts
deno fmt --check
deno lint
```

The tests cover the invite code alphabet, price parsing, URL normalization, every parse adapter against fixture HTML, oEmbed mapping with a mocked fetch, Apple identity token verification with a locally generated key, the Apple certificate chain machinery against the embedded root, the App Store status mapping, event validation with PII dropping, and the error envelope.

## Secrets

Set in the Supabase dashboard, or `supabase secrets set --env-file .env`.

| Name                        | Used by                                 | Notes                                                              |
| --------------------------- | --------------------------------------- | ------------------------------------------------------------------ |
| `SUPABASE_URL`              | every function                          | injected by the platform                                           |
| `SUPABASE_SERVICE_ROLE_KEY` | every function                          | injected by the platform; the only key that can touch the tables   |
| `APPLE_CLIENT_ID`           | `invite`, `entitlement`, `apple-revoke` | defaults to `app.corbie`; the `aud` an identity token must carry   |
| `APPLE_TEAM_ID`             | `apple-revoke`                          | ten character team id                                              |
| `APPLE_KEY_ID`              | `apple-revoke`                          | key id of the Sign in with Apple key                               |
| `APPLE_PRIVATE_KEY`         | `apple-revoke`                          | the `.p8` PKCS8 PEM; literal `\n` in the value is accepted         |
| `APPLE_ENV`                 | `appstore-notifications`                | `Sandbox` or `Production`; a payload from the other one is refused |
| `INSTAGRAM_OEMBED_TOKEN`    | `parse`                                 | optional; without it Instagram links return only url and source    |

`APPLE_PRIVATE_KEY` never leaves the Supabase secret store, and nothing here belongs in the app binary.

## Deploy

```
supabase link --project-ref <project-ref>
supabase db push
supabase functions deploy
```

`.github/workflows/supabase.yml` does both on a push to `main` that touches `server/**`, using the `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF` repository secrets, and runs the tests on pull requests.

Sandbox and production App Store notifications need different `APPLE_ENV` values, so they need two projects. Point the sandbox URL in App Store Connect at the project whose `APPLE_ENV` is `Sandbox`.

## Analytics

The four views live in the `analytics` schema, which is not exposed over the API:

- `analytics.onboarding_funnel` - devices per onboarding step, by week
- `analytics.paired_ratio` - redeemed invites against created spaces, by week
- `analytics.retention_d1_d7_d30` - weekly cohort of first `app_open`, share back on day 1, 7 and 30
- `analytics.trial_to_paid` - weekly cohort of `trial_started`, share that later purchased

Raw events are kept 30 days. `purge_expired_rows()` runs nightly through `pg_cron` when the extension is available.
