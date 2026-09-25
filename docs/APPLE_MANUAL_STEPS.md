# Apple steps only the founder can do

Module 21 part 2. Everything here needs your Apple ID or your Supabase login, so none of it was done
from the repo. Do them in this order: signing first, because the CloudKit step needs a signed build
on a device.

## 1. Let Xcode sign for the team (5 minutes)

`project.yml` now carries `DEVELOPMENT_TEAM: 735XXP9B5R` with automatic signing. This Mac has no code
signing identity yet (`security find-identity -v -p codesigning` finds none), so Xcode has to create
one.

1. Xcode, Settings, Accounts. If the developer Apple ID is not listed, press **+**, Apple Account, and
   sign in.
2. Select the account, select team `735XXP9B5R`, press **Manage Certificates**, then **+** and
   **Apple Development**. Close.
3. Open `Corbie.xcodeproj`, select the Corbie target, Signing & Capabilities. Team should read your
   team and each capability should show no red error. Repeat for CorbieWidgets and CorbieShare.
4. Connect an iPhone, pick it as the run destination, press Run once. The first run asks you to
   trust the developer on the phone: Settings, General, VPN & Device Management.

If a capability shows an error, the App ID in the developer portal is missing it. The app target
needs iCloud (CloudKit, container `iCloud.app.corbie`), App Groups (`group.app.corbie`), Push
Notifications, Sign in with Apple and Associated Domains. The widget and share targets need iCloud
and App Groups only.

## 2. Deploy the CloudKit schema to production (20 minutes)

What breaks if you skip it: TestFlight and App Store builds talk to the production CloudKit
environment. With no production schema, every save is refused, so pairing never completes and
nothing syncs between partners. Debug builds from Xcode use the development environment, so you
will not see the failure until a TestFlight build.

The development schema only contains record types that have been written at least once, so fill it
first.

1. In Xcode, Product, Scheme, Edit Scheme, Run, Arguments, Environment Variables: add
   `CORBIE_INIT_SCHEMA` with value `1`.
2. Run the Debug build on a device that is signed into iCloud. On launch the app calls
   `initializeCloudKitSchema` once, which creates every `CD_` record type in development. Then
   remove the variable again.
3. Open `https://icloud.developer.apple.com`, sign in with the developer Apple ID, choose CloudKit
   Database, and select the container `iCloud.app.corbie`.
4. With the environment switch on **Development**, open Schema, Record Types. You should see the
   `CD_` types for every entity (`CD_Space`, `CD_Member`, `CD_TaskItem`, `CD_Plan`, `CD_BusyInterval`
   and the rest). If the list is short, repeat step 2.
5. Press **Deploy Schema Changes** (in the left column, or at the top of the Schema page). Review
   the list of record types and indexes it is about to copy, and confirm.
6. Verify: switch the environment to **Production**, open Schema, Record Types. The same `CD_`
   types must be there with the same fields. A TestFlight build that pairs and syncs is the final
   proof.

Deploying is additive and cannot be undone: a field that reaches production stays there. Every
later model change needs the same two steps before the build that carries it goes out.

## 3. Three Apple secrets in Supabase (5 minutes)

Supabase dashboard, project `corbie`, Edge Functions, Secrets (or Project Settings, Edge Functions),
**Add new secret**, one at a time:

| Name | Value |
| --- | --- |
| `APPLE_TEAM_ID` | `735XXP9B5R` |
| `APPLE_KEY_ID` | `5FTU34GQVH` |
| `APPLE_PRIVATE_KEY` | the whole contents of `AuthKey_5FTU34GQVH.p8`, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |

Use the dashboard for the private key: `supabase secrets set` would leave it in your shell history.
The key is used by `/session`, which turns the one-time Sign in with Apple code into a refresh token
when someone signs in, and by `/apple-revoke`, which revokes the grant with that token when someone
deletes their account. Set the secrets before any test phone signs in: a phone that signed in
without them has no refresh token, and its grant is not revoked until it signs in again.

Verify from the repo, with a session token minted as in `server/DEPLOY.md` section 7:

```bash
cd ~/Desktop/codding/Corbie/server
bash scripts/smoke.sh "https://powtuiqqagdoiuqjeebr.supabase.co/functions/v1" "$(cat /tmp/corbie-token)"
```

The `POST /apple-revoke` row changes from `500 Server is missing APPLE_TEAM_ID` to a 400 or 502 from
Apple rejecting the fake authorization code. That still reads `pending`, which is correct: only a
real account deletion on a device can produce the 204.

## 4. Trader status, EU Digital Services Act (5 minutes)

App Store Connect, the Corbie app, App Information, Digital Services Act (or Business, depending on
the current layout).

What the two answers mean:

- **Trader**: you act for purposes related to your trade or business. Apple verifies an address,
  phone number and email, and shows them on the app's product page in EU storefronts.
- **Not a trader**: you are not acting for business purposes.

An individual who sells subscriptions is, on the ordinary reading of the Act, a trader, and v1 is
paid from day one. Answering "not a trader" to keep the address private would be an inaccurate
declaration. Because availability already excludes every EU storefront, there is no EU product page
for the contact details to appear on; the practical cost of answering "trader" today is the
verification step. If the EU is ever added to availability, the details become public on those
pages, which is the moment to consider a business address or a registered agent.

This is a reading of the rule, not legal advice. If the address question matters, ask the finance
and operations chat or an accountant before you answer.

## 5. Subscriptions, notifications and the In-App Purchase key

v1 is paid from day one, so the two subscriptions, their 14-day introductory offer, Billing Grace
Period, the two notification URLs, the In-App Purchase key with its four Supabase secrets
(`APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY`, `APPSTORE_APP_APPLE_ID` =
`6812410537`) and the License Agreement all have to exist before the sandbox test and the
submission. The steps, in order, are in `docs/RELEASE_CHECKLIST.md`, "App Store Connect before
submission". The sandbox test itself is `docs/TEST_PLAN.md` section 7.
