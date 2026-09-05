# Corbie server API

Base URL: `https://<project-ref>.supabase.co/functions/v1`. All functions are deployed with `verify_jwt = false`; authentication is done inside the function.

The server never sees couple data. It stores invite codes (15 min TTL), entitlement per `spaceId`, anonymous analytics events and an FX cache.

## Headers

| Header | Where | Value |
|---|---|---|
| `Authorization` | `invite`, `entitlement`, `apple-revoke` | `Bearer <Apple identity token>` (JWT from Sign in with Apple; verified against Apple JWKS, `aud` must equal `app.corbie`) |
| `X-Anon-Id` | `events`, `parse`, `fx` | device-local UUID, not linked to Apple ID |
| `X-App-Version` | all | `MARKETING_VERSION (BUILD)` |
| `Content-Type` | POST | `application/json` |

## Errors

Every non-2xx response is `{"error": "<code>", "message": "<human text>"}`. Codes: `unauthorized`, `invalid_request`, `not_found`, `expired`, `redeemed`, `rate_limited`, `upstream_failed`, `internal`.

## Endpoints

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
`source` is one of `amazon`, `target`, `etsy`, `sephora`, `nordstrom`, `zara`, `ikea`, `instagram`, `tiktok`, `generic`. Any field except `canonicalURL` and `source` may be `null`. For `instagram` and `tiktok` the function uses oEmbed: `imageURL` and `author` are filled, `title` and `price` are `null`. Cached 24 h by SHA-256 of the normalized URL. Upstream timeout 8 s; on failure returns `200` with only `canonicalURL` and `source` so the client falls back to manual entry.

### GET `/fx?base=USD`
Rate limited per IP. ECB rates via Frankfurter, cached 12 h per base.

Response `200`: `{"base": "USD", "date": "2026-09-05", "rates": {"EUR": 0.91, "GBP": 0.78, "CHF": 0.88, "CAD": 1.36, ...}}`

### POST `/appstore-notifications`
Called by Apple (App Store Server Notifications V2). Body is `{"signedPayload": "<JWS>"}`. The function verifies the JWS chain against Apple root certificates, decodes `signedTransactionInfo` and `signedRenewalInfo`, maps `appAccountToken` to `space_id` and upserts `entitlements`. Two deployments: `appstore-notifications` (production) and `appstore-notifications-sandbox` (sandbox), selected by `APPLE_ENV` secret. Responds `200` with empty body; Apple retries on non-2xx.

Status mapping: `SUBSCRIBED`, `DID_RENEW`, `DID_CHANGE_RENEWAL_STATUS`, `OFFER_REDEEMED` with `expiresDate` in the future become `active`; `DID_FAIL_TO_RENEW` with grace period become `grace`; `EXPIRED`, `GRACE_PERIOD_EXPIRED` become `expired`; `REFUND`, `REVOKE` become `revoked`.

### GET `/entitlement/{spaceId}`
Auth required.

Response `200`: `{"spaceId": "<uuid>", "status": "active", "productId": "app.corbie.yearly", "expiresAt": "2027-09-05T10:00:00Z", "updatedAt": "..."}`

`status` is one of `none`, `active`, `grace`, `expired`, `revoked`. Unknown space returns `200` with `status: "none"`.

### POST `/events`
Batch of anonymous events. Requires `X-Anon-Id`. Body:
```json
{"events": [{"name": "task_created", "props": {"assignee": "partner"}, "ts": "2026-09-05T10:00:00Z", "appVersion": "1.0 (12)", "locale": "en_US"}]}
```
Max 50 events per batch. Event names are validated against the allowlist in `docs/03_TECH_ARCHITECTURE.md` section 13. Props are limited to 10 keys of scalar values; keys named `email`, `name`, `phone`, `title`, `body`, `text`, `url` are dropped. Response `202` empty.

### POST `/apple-revoke`
Auth required. Used on account deletion.

Request: `{"authorizationCode": "<code from ASAuthorizationAppleIDCredential>"}` or `{"refreshToken": "..."}`.

The function exchanges the code for a refresh token with `client_secret` (ES256 JWT built from `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`) and calls `https://appleid.apple.com/auth/revoke`. Response `204`.

## Swift client

`APIClient` in `CorbieCore/Services` implements exactly these endpoints with typed request and response structs, `URLSession`, JSON with ISO 8601 dates, 3 retries with exponential backoff on 5xx and network errors, no retry on 4xx.
