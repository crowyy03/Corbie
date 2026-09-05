# Corbie server API

Base URL: `https://<project-ref>.supabase.co/functions/v1`. All functions are deployed with `verify_jwt = false`; authentication is done inside the function.

The server never sees couple data. It stores invite codes (15 min TTL), entitlement per `spaceId`, anonymous analytics events and an FX cache.

## Headers

| Header          | Where                                                 | Value                                                                                                                                                                                                                                                                                                                                                                                                              |
| --------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Authorization` | `session`, `invite`, `entitlement`, `apple-revoke`    | `Bearer <token>`. Either an Apple identity token (RS256 JWT from Sign in with Apple, verified against Apple JWKS, `iss` `https://appleid.apple.com`, `aud` `app.corbie`) or a Corbie session token issued by `POST /session` (HS256 JWT, `iss` `corbie`). Apple identity tokens live about ten minutes, so the client exchanges one for a session token right after sign-in and uses the session token afterwards. |
| `X-Anon-Id`     | `events` (required), `parse`, `fx` (accepted, unused) | device-local UUID, not linked to Apple ID                                                                                                                                                                                                                                                                                                                                                                          |
| `X-App-Version` | all                                                   | `MARKETING_VERSION (BUILD)`                                                                                                                                                                                                                                                                                                                                                                                        |
| `Content-Type`  | POST                                                  | `application/json`                                                                                                                                                                                                                                                                                                                                                                                                 |

No CORS headers are sent: the client is a native app and no browser origin is allowed. `OPTIONS` is answered with `405`.

Every response carries `cache-control: no-store` and `x-content-type-options: nosniff`.

## Errors

Every non-2xx response is `{"error": "<code>", "message": "<human text>"}`. Codes: `unauthorized`, `invalid_request`, `not_found`, `expired`, `redeemed`, `rate_limited`, `upstream_failed`, `internal`.

Status per code: `unauthorized` 401, `invalid_request` 400, `not_found` 404, `expired` 410, `redeemed` 410, `rate_limited` 429, `upstream_failed` 502, `internal` 500. A request with the wrong HTTP method is `invalid_request` with status `405`.

## Rate limits

A token bucket per IP and route lives in the `rate_limits` table; a full bucket refills over one hour. Exceeding it is `429 rate_limited`.

| Endpoint        | Requests per hour per IP |
| --------------- | ------------------------ |
| `session`       | 30                       |
| `invite`        | 30                       |
| `invite-redeem` | 60                       |
| `parse`         | 60                       |
| `fx`            | 120                      |
| `entitlement`   | 240                      |
| `events`        | 600                      |
| `apple-revoke`  | 10                       |

`appstore-notifications` is not rate limited: Apple calls it and retries on any non-2xx.

The bucket key is the address the gateway itself sets: `CF-Connecting-IP`, then `X-Real-IP`, and only then the last entry of `X-Forwarded-For`, which is the hop the gateway appended. Entries a caller puts in front of that are ignored, because a caller can send any `X-Forwarded-For` it likes. With none of those headers the key falls back to a hash of `X-Anon-Id`.

If the bucket cannot be read (database error) the request is allowed through, so a limiter outage never takes the API down.

## Endpoints

### POST `/session`

Auth required with an Apple identity token only (a session token is rejected here). Exchanges the short-lived Apple token for a Corbie session token.

Request: `{}`

Response `200`: `{"token": "<jwt>", "expiresAt": "2027-03-04T10:00:00Z"}`

The session token is an HS256 JWT signed with the `SESSION_SECRET` secret: claims `iss` = `corbie`, `sub` = SHA-256 hex of the Apple `sub`, `iat`, `exp` = 180 days. Every endpoint that requires auth accepts it in place of the Apple token; the server never stores it. The client keeps it in the Keychain under `server.session.token` and re-runs Sign in with Apple when it gets `401` back.

### POST `/invite`

Auth required. Creates a new invite code for a space and invalidates any previous active code for the same space.

Request: `{"spaceId": "<uuid>", "shareURL": "https://www.icloud.com/share/..."}`

Response `201`: `{"code": "K7M2QX", "expiresAt": "2026-09-05T12:15:00Z"}`

Code alphabet: `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, 6 characters. TTL 15 minutes.

### GET `/invite-redeem/{code}`

No auth (the code is the secret). Returns the share URL once and marks the invite redeemed.

Response `200`: `{"shareURL": "https://www.icloud.com/share/...", "spaceId": "<uuid>"}`

`404 not_found` unknown code, `410 expired`, `410 redeemed`.

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

`source` is one of `amazon`, `target`, `etsy`, `sephora`, `nordstrom`, `zara`, `ikea`, `instagram`, `tiktok`, `generic`. Any field except `canonicalURL` and `source` may be `null`. For `instagram` and `tiktok` the function uses oEmbed: `imageURL` and `author` are filled, `title` and `price` are `null`. Cached 24 h by SHA-256 of the normalized URL. Upstream timeout 8 s; on failure returns `200` with only `canonicalURL` and `source` so the client falls back to manual entry. A URL that points inside a network rather than at a shop is treated as such a failure and is never fetched.

### GET `/fx?base=USD`

Rate limited per IP. ECB rates via Frankfurter, cached 12 h per base.

Response `200`: `{"base": "USD", "date": "2026-09-05", "rates": {"EUR": 0.91, "GBP": 0.78, "CHF": 0.88, "CAD": 1.36, ...}}`

### POST `/appstore-notifications`

Called by Apple (App Store Server Notifications V2). Body is `{"signedPayload": "<JWS>"}`. The function verifies the JWS chain against Apple root certificates, decodes `signedTransactionInfo` and `signedRenewalInfo`, maps `appAccountToken` to `space_id` and upserts `entitlements`. The same function is deployed to a sandbox and a production project, told apart by the `APPLE_ENV` secret. Responds `200` with empty body; Apple retries on non-2xx.

Status mapping: `SUBSCRIBED`, `DID_RENEW`, `DID_CHANGE_RENEWAL_STATUS`, `OFFER_REDEEMED` with `expiresDate` in the future become `active`; `DID_FAIL_TO_RENEW` with a grace period becomes `grace`; `EXPIRED` and `GRACE_PERIOD_EXPIRED` become `expired`; `REFUND` and `REVOKE` become `revoked`.

### GET `/entitlement/{spaceId}`

Auth required.

Response `200`: `{"spaceId": "<uuid>", "status": "active", "productId": "app.corbie.yearly", "expiresAt": "2027-09-05T10:00:00Z", "updatedAt": "..."}`

`status` is one of `none`, `active`, `grace`, `expired`, `revoked`. Unknown space returns `200` with `status: "none"`.

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

Request: `{"authorizationCode": "<code from ASAuthorizationAppleIDCredential>"}` or `{"refreshToken": "..."}`.

The function exchanges the code for a refresh token with `client_secret` (ES256 JWT built from `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`) and calls `https://appleid.apple.com/auth/revoke`. Response `204`.

## Swift client

`APIClient` in `CorbieCore/Services` implements exactly these endpoints with typed request and response structs, `URLSession`, JSON with ISO 8601 dates, 3 retries with exponential backoff on 5xx and network errors, no retry on 4xx.

## Implementation notes

These are details the contract above leaves open, fixed by `server/supabase/functions`.

**Session.** Which kind of token a request carries is decided before anything is verified, from the header `alg` and the `iss` claim as they are written: `HS256`, or `iss` `corbie`, takes the session path, everything else goes to Apple JWKS. A token that calls itself a Corbie token is therefore never checked against Apple's keys, and `POST /session` refuses it outright with `401 unauthorized` instead of minting a session token from a session token.

Both paths hand the endpoint the same subject, the SHA-256 hex of the Apple `sub`, so an endpoint cannot tell the two apart and never sees the raw Apple identifier. `exp` and `iat` allow sixty seconds of clock skew, the same as identity tokens.

Nothing about a session token is written down, so an individual token cannot be revoked before its 180 days run out; rotating `SESSION_SECRET` invalidates every issued token at once. Without `SESSION_SECRET` set, `POST /session` answers `500 internal` and a session token is refused with `401 unauthorized`, which sends the client back to Sign in with Apple rather than letting an unverifiable token through.

**Invite.** `shareURL` must be `https` on `icloud.com` or a subdomain; anything else is `invalid_request`. Creating a code first expires every unredeemed code for that space, then inserts, retrying up to five times on a code collision. `invite-redeem` claims the row with a conditional update, so two devices racing the same code get one `200` and one `410 redeemed`. A code that is not six characters of the alphabet is `404 not_found`, same as an unknown code, so the endpoint does not tell a guesser which codes are well formed.

**Parse.** Before any fetch, and again on every redirect hop, the target is checked: only `http` and `https`, no explicit port other than 443, no bare IP address, no `localhost`, `.local`, `.internal`, `.home.arpa` or `.onion` host, and no host that resolves to a loopback, private, link local, carrier grade NAT, multicast or reserved address in either family, IPv4 mapped addresses included. Redirects are followed by hand, at most five hops, so an allowed public host cannot bounce the fetch into the internal network. Where the runtime exposes no DNS resolver the name based checks still apply. A blocked URL degrades exactly like an unreachable one: `200` with only `canonicalURL` and `source`.

The response body is read as a stream and abandoned once 3 MB have arrived, so an endless body cannot fill the worker's memory. The cache key is the SHA-256 of the canonical URL, so `/gp/product/ASIN?utm_source=x` and `/dp/ASIN` share one entry. Normalization strips `utm_*`, `fbclid`, `gclid`, `msclkid`, `igshid`, `ref`, `referrer` and friends everywhere, plus `tag`, `ascsubtag`, `linkCode`, `psc`, `th`, `qid` and the `pd_rd_*` / `pf_rd_*` family on Amazon, and rewrites Amazon product paths to `/dp/<ASIN>`. `a.co`, `amzn.to`, `amzn.eu` and `amzn.asia` are followed (max five hops) before normalizing. Responses are only cached when a title or an image was found, so a blocked page is retried next time rather than pinned for 24 h. A non-HTML content type is dropped.

`currency` is `null` whenever `price` is `null`. The currency is read from `product:price:currency`, JSON-LD `priceCurrency`, a three letter code in the price text (`EUR23.89` included) or a symbol; when none of those is present the price is still returned with a `null` currency and the client must ask.

**oEmbed.** TikTok uses the public `https://www.tiktok.com/oembed` endpoint. Instagram's oEmbed needs a Facebook app token: set `INSTAGRAM_OEMBED_TOKEN` to enable it. Without the token an Instagram link returns only `canonicalURL` and `source`, which is the same fallback the client already handles.

**FX.** Cached 12 h per base in `fx_rates`. If Frankfurter fails and a stale row exists, the stale row is served rather than an error; only a cold cache plus a failing upstream returns `502 upstream_failed`.

**App Store notifications.** The JWS `x5c` chain is verified in full: every certificate must be inside its validity window, each must be signed by the next, issuer and subject DER must match along the chain, and the last certificate must be byte-for-byte the Apple Root CA G3 embedded in `_shared/appleRootCA.ts` (SHA-256 `63343abf…3e9179`). Every certificate above the leaf must also be a certificate authority: basic constraints `cA=TRUE`, the `keyCertSign` key usage bit, and a path length constraint that still covers the certificates below it. The leaf must carry Apple's App Store signing extension `1.2.840.113635.100.6.11.1`, so an ordinary end entity certificate issued by Apple to some other developer cannot sign a notification. `signedTransactionInfo` and `signedRenewalInfo` are verified the same way, not merely decoded.

A payload whose `environment` differs from `APPLE_ENV` is rejected with `invalid_request`, so sandbox traffic cannot write production entitlements. A payload whose `bundleId` is not `APPLE_BUNDLE_ID` (default `app.corbie`), in the notification or in the decoded transaction or renewal info, is answered `200` and dropped: Apple signs every developer's notifications with the same leaf, so the bundle id is what ties a valid signature to this app. A notification with no `appAccountToken`, or one that is not a UUID, is answered `200` and dropped, because Apple would otherwise retry it forever. `payer_hash` is the SHA-256 of a salted `originalTransactionId`, never a user identifier.

The write goes through `entitlement_apply()`, not a plain upsert. The row keeps `signed_date` and `notification_uuid`, and the update is skipped when the incoming notification repeats the stored `notificationUUID` or was signed before the stored one. Apple retries a non-2xx five times over three days and states that notifications can arrive out of order, so without that guard a replayed `DID_RENEW` would overwrite a later `REFUND`. A skipped write is still answered `200`.

Sandbox and production need different `APPLE_ENV` values, which means two Supabase projects: a single project has one secret set. The function is named `appstore-notifications` in both.

**Events.** Names outside the allowlist in architecture section 13 are dropped silently rather than failing the batch, so an older or newer client never loses a whole upload. Props are capped at 10 keys, string values at 200 characters, and only strings, finite numbers, booleans and `null` survive. Keys named `email`, `name`, `phone`, `title`, `body`, `text`, `url` are dropped case-insensitively. Timestamps more than an hour in the future or more than 30 days in the past are replaced with the receive time.

**Retention.** `purge_expired_rows()` deletes events older than 30 days, invites older than a day, parse cache older than seven days and rate limit rows older than a day. It is scheduled nightly with `pg_cron` when the extension is available; where it is not, call it from any scheduler.

**Analytics.** The four views live in the `analytics` schema, which is not in the API schema list, and are granted to `service_role` only.

**Row level security.** Every table has RLS enabled and forced with no policies at all, and `anon` and `authenticated` hold no grants. Only the service role key used inside the functions can read or write.
