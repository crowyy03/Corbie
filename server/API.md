# Corbie server API

Base URL: `https://<project-ref>.supabase.co/functions/v1`. All functions are deployed with `verify_jwt = false`; authentication is done inside the function.

The server never sees couple data. It stores invite codes (15 min TTL), one row per App Store subscription with the `spaceId` it pays for, anonymous analytics events, an FX cache, a parse cache of the product links it fetched, and the monetization flag.

## Headers

| Header              | Where                                                                                              | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| ------------------- | -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Authorization`     | `session`, `invite`, `entitlement`, `apple-revoke`, `appstore-reconcile`                           | `Bearer <token>`. Either an Apple identity token (RS256 JWT from Sign in with Apple, verified against Apple JWKS, `iss` `https://appleid.apple.com`, `aud` `app.corbie`) or a Corbie session token issued by `POST /session` (HS256 JWT, `iss` `corbie`). Apple identity tokens live about ten minutes, so the client exchanges one for a session token right after sign-in and uses the session token afterwards. `appstore-reconcile` takes only the project's service role key. |
| `X-Anon-Id`         | `events` (required), `parse`, `fx`, `config` (rate limit key), `invite-redeem` (same device retry) | device-local UUID, not linked to Apple ID                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `X-App-Transaction` | `entitlement`, `entitlement/sync`                                                                  | `AppTransaction.shared.jwsRepresentation`, the proof of which App Store environment the build runs in. Optional: missing, unverifiable or Xcode-signed counts as Production                                                                                                                                                                                                                                                                                                        |
| `X-App-Version`     | all                                                                                                | `MARKETING_VERSION (BUILD)`                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `Content-Type`      | POST                                                                                               | `application/json`                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |

No CORS headers are sent: the client is a native app and no browser origin is allowed. `OPTIONS` is answered with `405`.

Every response carries `cache-control: no-store` and `x-content-type-options: nosniff`.

## Errors

Every non-2xx response is `{"error": "<code>", "message": "<human text>"}`. Codes: `unauthorized`, `invalid_request`, `not_found`, `expired`, `superseded`, `redeemed`, `rate_limited`, `upstream_failed`, `internal`.

Status per code: `unauthorized` 401, `invalid_request` 400, `not_found` 404, `expired` 410, `superseded` 410, `redeemed` 409, `rate_limited` 429, `upstream_failed` 502, `internal` 500. A request with the wrong HTTP method is `invalid_request` with status `405`.

## Rate limits

A token bucket per caller and route lives in the `rate_limits` table; a full bucket refills over one hour. Exceeding it is `429 rate_limited`. The caller is the IP address the gateway reports, or `X-Anon-Id` when there is none, and the key stores only an HMAC-SHA256 of that value under the `RATE_LIMIT_SALT` secret (`<route>:ip:<32 hex>` or `<route>:anon:<32 hex>`), never the address itself. Without the secret every rate-limited endpoint answers `500 Server is missing RATE_LIMIT_SALT`.

| Endpoint           | Requests per hour per IP |
| ------------------ | ------------------------ |
| `session`          | 30                       |
| `invite`           | 30                       |
| `invite-redeem`    | 60                       |
| `parse`            | 60                       |
| `fx`               | 120                      |
| `config`           | 120                      |
| `entitlement`      | 240                      |
| `entitlement/sync` | 30                       |
| `events`           | 600                      |
| `apple-revoke`     | 10                       |

`appstore-notifications` is not rate limited: Apple calls it and retries on any non-2xx. `appstore-reconcile` is not rate limited either: only the service role key gets in.

The bucket key is the address the gateway itself sets: `CF-Connecting-IP`, then `X-Real-IP`, and only then the last entry of `X-Forwarded-For`, which is the hop the gateway appended. Entries a caller puts in front of that are ignored, because a caller can send any `X-Forwarded-For` it likes. With none of those headers the key falls back to a hash of `X-Anon-Id`.

If the bucket cannot be read (database error) the request is allowed through, so a limiter outage never takes the API down.

## Endpoints

### POST `/session`

Auth required with an Apple identity token only (a session token is rejected here). Exchanges the short-lived Apple token for a Corbie session token.

Request: `{}`, or `{"authorizationCode": "<code from ASAuthorizationAppleIDCredential>"}` right after Sign in with Apple.

Response `200`: `{"token": "<jwt>", "expiresAt": "2027-03-04T10:00:00Z", "appleRefreshToken": "<token>"}`

`appleRefreshToken` is present only when the request carried an authorization code and Apple exchanged it. The code is single use and lives five minutes, so this is the only moment it can be turned into the refresh token that `POST /apple-revoke` needs when the account is deleted. The server does not keep the refresh token; the client stores it in the Keychain under `apple.refresh.token`. If the Apple key secrets are missing or Apple refuses the code, the session is still issued without the field. A malformed `authorizationCode` is `400 invalid_request`.

The session token is an HS256 JWT signed with the `SESSION_SECRET` secret: claims `iss` = `corbie`, `sub` = SHA-256 hex of the Apple `sub`, `iat`, `exp` = 180 days. Every endpoint that requires auth accepts it in place of the Apple token; the server never stores it. The client keeps it in the Keychain under `server.session.token`. A `401` is surfaced as an error; nothing exchanges a new token on its own, so a token that outlives its 180 days is replaced only when the person signs in again.

### POST `/invite`

Auth required. Creates a new invite code for a space. Every older code of that space that is still live (not redeemed, not superseded, not expired) is marked superseded at that moment: its `expires_at` stays as it was, and redeeming it answers `410 superseded` from then on, so the partner hears that a newer code exists rather than that the code ran out.

Request: `{"spaceId": "<uuid>", "shareURL": "https://www.icloud.com/share/..."}`

Response `201`: `{"code": "K7M2QX", "expiresAt": "2026-09-05T12:15:00Z"}`

Code alphabet: `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, 6 characters. TTL 15 minutes.

### GET `/invite-redeem/{code}`

No auth (the code is the secret). Returns the share URL and marks the invite redeemed by the caller.

Optional header `X-Anon-Id` (the device UUID). The server keeps only its salted digest in `redeemed_by`. The same `X-Anon-Id` asking again for the same code within 15 minutes of the first redeem gets the same `200` again, even when the code's own 15 minutes are over by then, so a join that was interrupted after the redeem (the app killed while CloudKit was still accepting) can be retried with the same code. Any other caller, or the same one later than that, gets `409 redeemed`. Without `X-Anon-Id` a code is single use: the second call is `409 redeemed`. A malformed `X-Anon-Id` is `400 invalid_request`.

Response `200`: `{"shareURL": "https://www.icloud.com/share/...", "spaceId": "<uuid>"}`

Checked in this order: `404 not_found` unknown code, `410 superseded` a newer code of the same space replaced it, `409 redeemed` used by someone else (or by this device more than 15 minutes ago), `410 expired` older than 15 minutes. The client keys on the error code, not the status; `redeemed` was `410` before 2026-09-21.

### POST `/parse`

Rate limited per IP (60/hour). Extracts product data from a URL. Never returns HTML.

Request: `{"url": "https://www.amazon.com/dp/B0..."}`

Response `200`:

```json
{
  "canonicalURL": "https://www.amazon.com/dp/B0...",
  "source": "amazon",
  "title": "Product name",
  "price": 24.99,
  "currency": "USD",
  "imageURL": "https://...",
  "author": null
}
```

`source` is one of `amazon`, `target`, `etsy`, `sephora`, `nordstrom`, `zara`, `ikea`, `instagram`, `tiktok`, `generic`. Any field except `canonicalURL` and `source` may be `null`. For `instagram` and `tiktok` the function uses oEmbed: `imageURL` and `author` are filled, `title` and `price` are `null`. Cached 24 h by SHA-256 of the normalized URL. Upstream timeout 8 s; on failure returns `200` with only `canonicalURL` and `source` so the client falls back to manual entry. The same bare answer comes back when a product link is redirected somewhere that is not a product: IKEA sends a product that is not sold in that country to the category page (`/us/en/cat/products-products/`), which would otherwise read as a product called "Products". A URL that points inside a network rather than at a shop is treated as such a failure and is never fetched.

### GET `/fx?base=USD`

Rate limited per IP. ECB rates via Frankfurter, cached 12 h per base.

Response `200`: `{"base": "USD", "date": "2026-09-05", "rates": {"EUR": 0.91, "GBP": 0.78, "CHF": 0.88, "CAD": 1.36, ...}}`

### GET `/config`

No auth. Rate limited per IP (120/hour). Returns the server-controlled monetization flag, read from the `monetization_enabled` row of `app_config`.

Response `200`: `{"monetizationEnabled": true}`

A missing row answers `true`: v1 is paid from day one. A database error, or a stored value that is not a JSON boolean, answers `500 internal` and never a flag value.

### POST `/appstore-notifications`

Called by Apple (App Store Server Notifications V2) for both environments at the same URL. Body is `{"signedPayload": "<JWS>"}`. The function verifies the JWS chain against the Apple root, verifies `signedTransactionInfo` and `signedRenewalInfo` the same way, and writes one row per subscription (`originalTransactionId`) in the environment the signed payload names. Responds `200` with an empty body whenever the notification was stored or deliberately dropped. A payload that fails the signature check is `401`, a missing `signedPayload` `400`, and a failed database write `500`; Apple retries every non-2xx.

The environment is `data.environment` of the signed payload; the decoded transaction and renewal info must name the same one, otherwise the notification is dropped. A Production notification must also carry `data.appAppleId` equal to `APPSTORE_APP_APPLE_ID` (default `6812410537`); Sandbox notifications carry no app id. Sandbox and Production rows never share a key, so a sandbox purchase cannot touch what a production build reads.

State comes from `data.status`, Apple's own status as of the notification's `signedDate`: `1` active, `2` expired, `3` in_billing_retry, `4` in_grace_period, `5` revoked. Only when a notification carries no status is it derived from the type and subtype as before (renewal events active while `expiresDate` is ahead or while the grace window is open, `DID_FAIL_TO_RENEW` grace or billing retry, `EXPIRED` and `GRACE_PERIOD_EXPIRED` expired).

`REFUND` and `REVOKE` revoke the subscription only when the refunded transaction is its latest: the stored `latest_transaction_id`, or one that ends no earlier than the stored period. A refund of an older period is answered `200` and changes nothing. `REFUND_REVERSED` restores the state from `data.status` under the same rule. `CONSUMPTION_REQUEST`, `REFUND_DECLINED` and `TEST` never change state, and neither do payloads without a `data` object (`RENEWAL_EXTENSION` with subtype `SUMMARY`, `RESCIND_CONSENT`).

The subscription is linked to the space its `appAccountToken` names (the transaction's, then the renewal info's). A notification without a token is stored against its `originalTransactionId` with no space and linked later by `POST /entitlement/sync`. A token moves a linked subscription only when the notification was signed after the last link.

### GET `/entitlement/{spaceId}`

Auth required. Optional header `X-App-Transaction`.

Response `200`: `{"spaceId": "<uuid>", "environment": "Production", "status": "active", "productId": "app.corbie.yearly", "expiresAt": "2027-09-05T10:00:00Z", "updatedAt": "..."}`

`environment` is the one the caller proved with `X-App-Transaction`: `Sandbox` only when the header verifies against the Apple root, names bundle `APPLE_BUNDLE_ID` and has `receiptType` `Sandbox`. A missing, unverifiable or Xcode-signed proof, or one for another bundle, is `Production`. The answer is that environment's entitlement only.

The entitlement is the best of the space's subscriptions in that environment: `active` first, then `in_grace_period`, then `in_billing_retry`, then anything else, and within the same status the one that ends latest. A space two partners both pay for stays paid while either subscription is.

`status` is one of `none`, `active`, `in_grace_period`, `in_billing_retry`, `expired`, `revoked`. `expiresAt` is the grace period end for `in_grace_period` and `in_billing_retry`, falling back to the transaction's `expiresDate`, and the transaction's `expiresDate` for every other status. The client treats `active` and `in_grace_period` as premium, and `in_billing_retry` as premium only while `expiresAt` is still ahead. A space with no subscription in that environment returns `200` with `status: "none"` and the other fields `null`.

### POST `/entitlement/sync`

Auth required. Rate limited per IP (30/hour). Header `X-App-Transaction` as for `GET`.

Request: `{"spaceId": "<uuid>", "signedTransaction": "<Transaction.jwsRepresentation>"}`

Response `200`: the `GET` body plus `"reconciled": true|false`.

The server verifies the signed transaction against the Apple root and takes its `originalTransactionId` and environment. That environment must equal the one `X-App-Transaction` proves, otherwise `400 invalid_request`; an unverifiable transaction is `401 unauthorized`. It then asks the App Store Server API (Get All Subscription Statuses on the host of that environment) for the subscription's current state and stores it. When Apple's `appAccountToken` for the subscription is not `spaceId`, it calls Set App Account Token so that the current and future renewals carry `spaceId`, and links the row to `spaceId`: one subscription pays for exactly one space, and holding the purchaser's signed transaction is the authorization to move it.

`reconciled` is `true` when Apple answered and, where needed, accepted the new token. When the API secrets are missing or Apple fails, the server applies the signed transaction itself (active while its `expiresDate` is ahead, revoked when it carries a `revocationDate`), still links the row to `spaceId`, and answers `200` with `reconciled: false`. Without the new token at Apple, a later renewal signed after the link can move the row back to the old space until the app syncs again.

The app calls it after every successful purchase, after Restore Purchases, and when it finds its own active subscription whose `appAccountToken` is not the current space.

### POST `/appstore-reconcile`

Auth: `Authorization: Bearer <service role key>`, nothing else. Body is optional: `{"days": 3}`.

Re-reads, through Get All Subscription Statuses, up to 60 subscriptions whose state could be stale: `active`, `in_grace_period` or `in_billing_retry`, and either never checked, not checked for a day, past their end, or in billing retry. The answer is stored with Apple's `appAccountToken` as the space. Then it replays Get Notification History (`onlyFailures`, the last `days` days, at most 179 in Production and 29 in Sandbox, 10 pages of 20 per environment) through the same code as `appstore-notifications`; a notification already stored is skipped by its `notificationUUID` or `signedDate`, so the replay is idempotent.

Response `200`: `{"configured": true, "checked": 3, "changed": 1, "checkFailures": 0, "replayed": {"Production": 2, "Sandbox": 0}, "replayFailures": {"Production": 0, "Sandbox": 0}}`. Without the App Store Server API secrets it answers `200` with `configured: false` and does nothing.

### POST `/events`

Batch of anonymous events. Requires `X-Anon-Id`. Body:

```json
{
  "events": [
    {
      "name": "task_created",
      "props": { "assignee": "partner" },
      "ts": "2026-09-05T10:00:00Z",
      "appVersion": "1.0 (12)",
      "locale": "en_US"
    }
  ]
}
```

Max 50 events per batch. Event names are validated against the allowlist in `docs/03_TECH_ARCHITECTURE.md` section 13. Props are limited to 10 keys of scalar values; keys named `email`, `name`, `phone`, `title`, `body`, `text`, `url` are dropped. Response `202` empty.

### POST `/apple-revoke`

Auth required. Used on account deletion.

Request: `{"refreshToken": "..."}`, the token `POST /session` returned at sign in. `{"authorizationCode": "..."}` is still accepted, but a code is dead five minutes after sign in, so the app sends only the refresh token and sends nothing when it has none.

The function builds a `client_secret` (ES256 JWT from `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`), exchanges a code for a refresh token when it got a code, and calls `https://appleid.apple.com/auth/revoke`. Response `204`.

## Swift client

`APIClient` in `CorbieCore/Services` covers every endpoint except `POST /session`, which lives in `Corbie/Features/Pairing/SessionService.swift`, with typed request and response structs, `URLSession`, JSON with ISO 8601 dates, 3 retries with exponential backoff on 5xx and network errors, and a retry on `429` when `Retry-After` is short enough. Every other 4xx is raised as it is.

## Implementation notes

These are details the contract above leaves open, fixed by `server/supabase/functions`.

**Session.** Which kind of token a request carries is decided before anything is verified, from the header `alg` and the `iss` claim as they are written: `HS256`, or `iss` `corbie`, takes the session path, everything else goes to Apple JWKS. A token that calls itself a Corbie token is therefore never checked against Apple's keys, and `POST /session` refuses it outright with `401 unauthorized` instead of minting a session token from a session token.

Both paths hand the endpoint the same subject, the SHA-256 hex of the Apple `sub`, so an endpoint cannot tell the two apart and never sees the raw Apple identifier. `exp` and `iat` allow sixty seconds of clock skew, the same as identity tokens.

Nothing about a session token is written down, so an individual token cannot be revoked before its 180 days run out; rotating `SESSION_SECRET` invalidates every issued token at once. Without `SESSION_SECRET` set, `POST /session` answers `500 internal` and a session token is refused with `401 unauthorized`, which sends the client back to Sign in with Apple rather than letting an unverifiable token through.

**Invite.** `shareURL` must be `https` on `icloud.com` or a subdomain; anything else is `invalid_request`. Creating a code inserts it first, retrying up to five times on a code collision, and only then sets `superseded_at` on the space's live codes created before it, so a failed insert never leaves the space without a working code and two codes made at the same moment do not kill each other. `invite-redeem` claims the row with one conditional update (`redeemed_at is null`, `superseded_at is null`, not expired) that also writes `redeemed_by`; a caller whose claim finds the row already taken reads it again and gets the answer for what the winner did, so two devices racing the same code get one `200` and one `409 redeemed`, and one device racing itself gets two `200`. `redeemed_by` is the HMAC-SHA256 of `X-Anon-Id` under `RATE_LIMIT_SALT`, cut to 32 hex characters, the same helper as the rate limit key (`_shared/hash.ts`); a check constraint keeps anything else out of the column. A code that is not six characters of the alphabet is `404 not_found`, same as an unknown code, so the endpoint does not tell a guesser which codes are well formed.

**Parse.** The fetch carries the header set mobile Safari sends (`user-agent` of an iPhone, `accept`,
`upgrade-insecure-requests`, the four `sec-fetch-*` headers) and an `accept-language` built from the
country of the host, so a `.de` shop is asked in German and a `.com` shop in English. Shops that block
datacenter addresses still answer `403`; that is an address block, not a header one
(`docs/KNOWN_ISSUES.md`). A result with neither a title nor an image is not written to `parse_cache`,
so a later attempt reaches the shop again instead of replaying the failure for 24 hours.

A shop adapter may name its product paths (`isProductPath`; IKEA: a `/p/` segment). When the pasted
link is a product path and the page the redirects end on is not, the answer is the bare result and
nothing is cached. The rule looks at the final URL rather than at the page, because IKEA's own
product pages no longer carry the `pip-` classes the adapter reads (checked 2026-09-21: they are
`pipcom-` now), and a category such as `/us/en/cat/billy-bookcases-58288/` carries two dozen JSON-LD
`Product` entries, so "no product markers" would call a real product page a category and a category
a product.

Before any fetch, and again on every redirect hop, the target is checked: only `http` and `https`, no explicit port other than 443, no bare IP address, no `localhost`, `.local`, `.internal`, `.home.arpa` or `.onion` host, and no host that resolves to a loopback, private, link local, carrier grade NAT, multicast or reserved address in either family, IPv4 mapped addresses included. Redirects are followed by hand, at most five hops, so an allowed public host cannot bounce the fetch into the internal network. Where the runtime exposes no DNS resolver the name based checks still apply. A blocked URL degrades exactly like an unreachable one: `200` with only `canonicalURL` and `source`.

The response body is read as a stream and abandoned once 3 MB have arrived, so an endless body cannot fill the worker's memory. The cache key is the SHA-256 of the canonical URL, so `/gp/product/ASIN?utm_source=x` and `/dp/ASIN` share one entry. Normalization strips `utm_*`, `fbclid`, `gclid`, `msclkid`, `igshid`, `ref`, `referrer` and friends everywhere, plus `tag`, `ascsubtag`, `linkCode`, `psc`, `th`, `qid` and the `pd_rd_*` / `pf_rd_*` family on Amazon, and rewrites Amazon product paths to `/dp/<ASIN>`. `a.co`, `amzn.to`, `amzn.eu` and `amzn.asia` are followed (max five hops) before normalizing. Responses are only cached when a title or an image was found, so a blocked page is retried next time rather than pinned for 24 h. A non-HTML content type is dropped.

`currency` is `null` whenever `price` is `null`. The currency is read from `product:price:currency`, JSON-LD `priceCurrency`, a three letter code in the price text (`EUR23.89` included) or a symbol; when none of those is present the price is still returned with a `null` currency and the client must ask.

**oEmbed.** TikTok uses the public `https://www.tiktok.com/oembed` endpoint. Instagram's oEmbed needs a Facebook app token: set `INSTAGRAM_OEMBED_TOKEN` to enable it. Without the token an Instagram link returns only `canonicalURL` and `source`, which is the same fallback the client already handles.

**FX.** Cached 12 h per base in `fx_rates`. If Frankfurter fails and a stale row exists, the stale row is served rather than an error; only a cold cache plus a failing upstream returns `502 upstream_failed`.

**Config.** `monetizationEnabled` is `false` only when the row says `false`, and `true` when the row says `true` or does not exist. When the read fails, or the row holds anything other than a JSON `true` or `false`, the endpoint answers `500 internal` instead of falling back to a value. The client contract is to keep the last value it fetched when a request fails, and to treat a value it never fetched as `true`. An error therefore leaves every app where it was. The value is read on every request, with no cache on the server. Migration 0006 seeded the live row with `false`; the founder flips it at launch, no migration does.

**App Store notifications.** The JWS `x5c` chain is verified in full: every certificate must be inside its validity window, each must be signed by the next, issuer and subject DER must match along the chain, and the last certificate must be byte-for-byte the Apple Root CA G3 embedded in `_shared/appleRootCA.ts` (SHA-256 `63343abf…3e9179`). Every certificate above the leaf must also be a certificate authority: basic constraints `cA=TRUE`, the `keyCertSign` key usage bit, and a path length constraint that still covers the certificates below it. The leaf must carry Apple's App Store signing extension `1.2.840.113635.100.6.11.1`, so an ordinary end entity certificate issued by Apple to some other developer cannot sign a notification. `signedTransactionInfo` and `signedRenewalInfo` are verified the same way, not merely decoded.

A payload whose `bundleId` is not `APPLE_BUNDLE_ID` (default `app.corbie`), in the notification or in the decoded transaction or renewal info, is answered `200` and dropped: Apple signs every developer's notifications with the same leaf, so the bundle id, and in Production the app id, is what ties a valid signature to this app.

Writes go through `subscription_apply()`, not a plain upsert, keyed by `(environment, original_transaction_id)`. The row keeps `signed_date` and `last_notification_uuid`, and a state change is skipped when the incoming notification repeats the stored `notificationUUID` or was signed before the stored one. Apple retries a non-2xx five times over three days in Production (once in Sandbox) and states that notifications can arrive out of order, so without that guard a replayed `DID_RENEW` would overwrite a later `REFUND`. A skipped write is still answered `200`. A state read from the App Store Server API is ordered by the time of the request, because it is Apple's answer as of that moment.

**App Store Server API.** `_shared/appStoreServerApi.ts` signs a fresh ES256 JWT per request with the In-App Purchase key: header `alg` `ES256`, `kid` `APPSTORE_KEY_ID`, `typ` `JWT`; claims `iss` `APPSTORE_ISSUER_ID`, `iat`, `exp` twenty minutes later, `aud` `appstoreconnect-v1`, `bid` `APPLE_BUNDLE_ID`. Production calls go to `https://api.storekit.apple.com`, Sandbox calls to `https://api.storekit-sandbox.apple.com`, each with a ten second timeout. Without `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID` or `APPSTORE_PRIVATE_KEY` the client is not built at all: sync answers with `reconciled: false` and reconcile with `configured: false`. An unreadable key or a failed call is logged and handled the same way; no function fails because of it.

**Events.** Names outside the allowlist in architecture section 13 are dropped silently rather than failing the batch, so an older or newer client never loses a whole upload. Props are capped at 10 keys, string values at 200 characters, and only strings, finite numbers, booleans and `null` survive. Keys named `email`, `name`, `phone`, `title`, `body`, `text`, `url` are dropped case-insensitively. Timestamps more than an hour in the future or more than 30 days in the past are replaced with the receive time.

**Retention.** `purge_expired_rows()` deletes events older than 30 days, invites older than a day, parse cache older than seven days and rate limit rows older than a day. It is scheduled nightly with `pg_cron` when the extension is available; where it is not, call it from any scheduler. Subscription rows are kept: Apple can resubscribe an old `originalTransactionId` at any time.

**Analytics.** The five views live in the `analytics` schema, which is not in the API schema list, and are granted to `service_role` only. `analytics.entitlement_status` counts spaces per environment and status from `public.space_entitlements`.

**Row level security.** Every table has RLS enabled and forced with no policies at all, and `anon` and `authenticated` hold no grants on any table, view or function. Only the service role key used inside the functions can read or write. `space_entitlements` and `analytics.entitlement_status` are `security_invoker` views and the subscription functions run as the caller, so they read with the service role's rights and nobody else's.
