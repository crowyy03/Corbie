# Known issues

Found in the QA pass and not fixed there. Anything fixed in that pass is in `docs/DECISIONS.md`
instead. Severity: **blocker** stops a submission, **major** ships a broken feature, **minor** is
wrong but survivable.

Last checked against the build in this worktree on 2026-09-06, Xcode 26.6, iOS 26.5 runtime, on
iPhone 17 Pro Max QA, iPhone 17e QA and iPhone 17 Badge.

## Blockers

### Pairing failures now have names

Every step of an invite and a join says what went wrong and writes one log line:
`docs/PAIRING_FAILURES.md` has the table of step, screen text and log line, including the App Group
and keychain probe that runs at launch in all three targets. Nothing in that table has run on two
real phones yet.

### The server base URL ships empty

RESOLVED 12-09, and since 18-09 a build without it cannot reach a server at all: `APIClient` refuses
the call and the app says "This build has no server address." (`docs/DECISIONS.md`). If link parsing
comes back empty on a device, check Settings, Developer, Server, or the `server` log line at launch.

`CORBIE_SERVER_URL` in `project.yml` carries the live Supabase project ref
`powtuiqqagdoiuqjeebr`, it reaches the app and the share extension through their Info plists, and
`ServerConfiguration.fromBundle` builds `https://powtuiqqagdoiuqjeebr.supabase.co/functions/v1` from
it. The five migrations are applied on that project, all nine functions are deployed, and
`server/scripts/smoke.sh` answers 15 pass, 0 fail, 2 pending against it.

## Minor

### The Us counters show a dash when there is nothing to count

`UsHubView.counterColumn` renders `Text(value.map { $0.formatted() } ?? "-")` in the 56pt counter
font (`Corbie/Features/Us/UsHubView.swift:108`). On a new space with no together-since date and no
upcoming date, both columns render a hyphen at counter size, which reads as a redaction bar rather
than as "nothing yet".

Reproduce: fresh install, skip the together-since date in onboarding, open the Us hub. Screenshot
`promax_en_light/us_hub.png`.

Fix, for the founder to decide: drop the number entirely when there is nothing to count and let the
mono caption carry the state, which is what `us.counters.empty` already says.

### A list item exposes two buttons with the same VoiceOver label

`ListItemRow` builds a checkbox button labelled with the item title
(`Corbie/Features/Plans/Lists/ListItemRow.swift:34`) and a details button whose only content is the
same title (`:41`). VoiceOver announces "Milk, button" twice in a row and only the value
("ticked" / "not ticked") tells them apart.

Reproduce: a list with one item that has no place and no note, VoiceOver on, swipe through the row.

Fix: give one of them a label that says what it does, the way the Today row does with
`today.row.check` ("Tick %@"). That needs a new catalog key and it changes what
`CorbieUITests/PlansUITests` and `SmokeTabsUITests` query, so it belongs to the Plans module rather
than to a QA patch.

### An automated run can never show a StoreKit price on the paywall

`Products.storekit` reaches the Run action only, so `xcodebuild test` opens the paywall with no
products and it renders `paywall.state.unavailable` ("The App Store did not answer") instead of the
two offers. `QAAppearanceUITests.testThePaywallShowsWhatAppReviewLooksFor` therefore asserts the
headline, Restore, the two legal links and the auto-renew sentence, then skips the price and period
check with that reason. It is the one skip in a green run.

Two routes were tried and neither works from the command line. `storeKitConfiguration` under
`schemes.Corbie.test` is accepted by XcodeGen 2.46 and silently dropped: the generated
`Corbie.xcscheme` carries `StoreKitConfigurationFileReference` under `LaunchAction` only. A
`Corbie.xctestplan` with `defaultOptions.storeKitConfigurationFileReference` is read (the scheme
gains a `TestPlans` block and the run reports `XCODE_TEST_PLAN_NAME`), but the configuration never
reaches the app: nothing named StoreKit appears in the generated `.xctestrun`, the paywall still
reports no products, and pointing the same key at a file that does not exist builds and runs without
a word of complaint, so the key is ignored rather than misspelt.

Fix: none from `xcodebuild` on Xcode 26.6. The price is a manual check through the Xcode Run action,
which does carry the configuration (`docs/TEST_PLAN.md` section 8).

### Navigation bar items are 36 points tall

`UsPill` asks for `.frame(minWidth: 44, minHeight: 44)`
(`Packages/CorbieCore/Sources/CorbieCore/Design/Components/UsPill.swift:22`) but inside a
`ToolbarItem` the bar constrains it: the QA session before this one measured the pill at 73 by 36
points on iPhone 17 Pro Max and the toolbar Save button at 36 points tall as well. This session did
not re-measure. Whether the system still hands those items a 44 point touch region was never
measured at all, so `QATapTargetUITests` checks only the controls the app lays out itself (filter
chip, Take, Who segment, due toggle, Today checkbox, appearance segment) and leaves the bar items
out.

Reproduce: any UI test, `print(app.usPill.frame)` after `launchSignedIn()`.

Fix, if the founder wants the pill visually bigger: give it its own row instead of a toolbar item, or
accept the bar height. Nothing to change if the system region is enough.

### Notifications are asked for once and never re-offered in the app

If the first request is denied, the only route back is Settings, Notifications, "Open iOS Settings".
That is a real route and there is no dead end
(`QAPermissionsUITests.testDeniedNotificationsAreReportedInSettingsWithAWayBack`), but nothing in the
feature screens hints that a reminder was not scheduled: `TaskDueNotifications` and the capsule
editor swallow the refusal silently. Worth a one-line hint next to the due date toggle once someone
has denied.

### Free time and half the Us badge cannot be finished by one person

A solo space can raise the badge dot from an unanswered vote it created itself
(`CorbieUITests/UsBadgeUITests`), from an unopened capsule, and from a person whose birthday falls
inside fourteen days with no gift picked (`CorbieUITests/QAUsBadgeUITests`). The two remaining
triggers in `UsBadgeRule` need a partner: a wish added by the partner, and a gift not picked for the
partner's own birthday or the anniversary, which `RadarService.partnerStatus` reads from the partner's
wishes. The same holds for free time: `FreeTimeView` shows "Free time needs two calendars" without a
partner, so the slot list, the filters and the "Ask them" path are two-Apple-ID checks
(`docs/TEST_PLAN.md` section 4).

### Luxury and bot-protected shops cannot be read from the server

Their site answers our server with `403` because the request comes from a datacenter address: Supabase
Edge Functions run in the cloud, and those ranges are blocked wholesale. Checked on 2026-09-18 with a
full mobile-Safari header set, including the same `Accept-Language` a phone in that country sends: the
answer stays `403`, so the gate is the address, not the headers.

What the person sees: the link is kept, "could not read this link - fill it in by hand" appears under
the field, and the name, price and photo are typed in by hand. Nothing is lost, the wish saves.

What the server does about it anyway:

- It sends the whole mobile-Safari header set (`_shared/parse/browserHeaders.ts`), with the language
  taken from the country of the host, which is enough for shops that gate on headers rather than on
  the address.
- A result that carries neither a title nor an image is never written to `parse_cache`
  (`isWorthCaching`), so the next attempt goes out to the shop again instead of replaying a stored
  failure for a day. A page that answers with a title, even a poor one, is cached for 24 hours as
  before.

The v1.1 answer is to parse on the device when the server comes back empty: the phone fetches the page
from the person's own address, which is what the competitors appear to do, and reads the same
`og:` and JSON-LD tags. It needs an amendment to `CLAUDE.md` and `docs/03_TECH_ARCHITECTURE.md`, which
say today that the client calls no third party, and it hands the shop the person's IP address, which
is what opening the link in Safari would do anyway. Not in v1.

Zara does not need the datacenter to refuse: it answers every client, a home address with the iPhone
Safari header set included, with an Akamai Bot Manager challenge page instead of the product. The
page is a `200` of about 2 KB with a `bm-verify` token, a meta refresh back to the same URL carrying
that token, an empty `<title>`, and no `og:` tags or JSON-LD; only a browser that runs its script is
let through to the product page. Rechecked on 2026-09-21 with curl and the iPhone Safari headers:
`200`, 2262 bytes, `bm-verify`, refresh after 5 seconds. The server reads nothing from that page, so
nothing is cached and the person fills the wish in by hand, as above. For the v1.1 fallback this means
the phone has to load the page in a hidden `WKWebView` and read the tags once the challenge has passed;
fetching it with `URLSession` gets the same challenge page the server gets.

### A widget tick or a shared wish reaches the partner only after the app runs

Since 2026-09-17 only the app syncs with iCloud (`docs/DECISIONS.md`, persistence fix round A). The
widget extension, App Intents running outside the app and the share extension write straight into
the shared store and stop there. The change shows on this phone's widgets at once, but it is uploaded
only when Corbie itself next runs on this phone and exports it. A task ticked on the Home Screen, a
task taken from the Free tasks widget, or a wish added from the share sheet therefore reaches the
partner after the next time this person opens Corbie, or when iOS happens to resume it in the
background.

Reproduce: two paired phones, Corbie closed on A. Tick a task on A's Tasks widget. B does not change
until A opens Corbie. `docs/TWO_DEVICE_TEST_SESSION.md` step 8.

Fix, if the delay matters: have the extensions ask the app to run (a background task request or a
push), which v1 does not do.

### Leaving can stop halfway

`CloudKitSharing.leave` checks the network, removes the participant's own member row, waits for that
removal to upload, and only then removes the share membership. If that last call fails, the row is
already gone but the person is still in the share. Tapping "Leave space" or "Delete account" again
finishes it, also when the share record was already deleted. If the app is relaunched first, the
session finds no member and opens onboarding, which reuses the joined space still in the store, so the
person comes back as a new member instead of leaving.

Not seen on a device; found by reading the code.

### A partner who deletes the app stays the partner

Deleting Corbie does not take anyone out of the CloudKit share, so the owner's cleanup
(`DepartedMemberRule`) still sees an accepted participant and keeps the member. Only leaving in the
app, deleting the account in the app, or losing access to the share frees the owner to invite someone
else.

### A partner who leaves and rejoins before the owner's app runs keeps the old row

If the removal of the leaving partner's row did not upload and they join again through the old link
before the owner's phone ran its check, the share lists an accepted participant again and the old row
stays next to the new one. `partner(of:)` returns the earlier row, so the owner sees the old profile
and new assignments go to it. The fix is to store the participant's CloudKit user record name on the
member row when they join and match participants by it, which needs a model field.

### Deleting the account without iCloud leaves the iCloud records

With no iCloud account or a restricted one on the phone, account deletion wipes the phone and revokes
Sign in with Apple, but the records in the iCloud account that was used before cannot be reached from
this device. Signing in to that iCloud account again and deleting the account once more removes them.

### The owner's cleanup needs something to wake it

When a partner leaves and the removal of their row did not upload in time, the owner's phone removes
the row itself, but only on launch, on returning to the foreground, or after a synced change. An owner
who keeps Corbie open on one screen with no incoming changes keeps seeing the old partner until one of
those happens.

## Цены на экранах оплаты не проверяются автотестом

`CorbieUITests/PaywallScreensUITests` доходит до `TrialOfferView` и `ComparisonView` и проверяет их тексты, но не карточки с ценами: в прогоне через `xcodebuild test` StoreKit не подхватывает `Products.storekit`. В логе симулятора клиент уходит в Sandbox (`Requesting Media API product batch ["app.corbie.monthly", "app.corbie.yearly"]`) и запрос падает без сети, экран показывает `The App Store did not answer`. XcodeGen 2.46 умеет класть `storeKitConfiguration` только в Run-действие схемы, ручная правка `Corbie.xcscheme` не помогает и стирается генерацией.

Что это значит: арифметику годовой цены и скидки держат юнит-тесты `CorbieTests/PaywallScreensTests`, а карточки цен проверяются руками запуском из Xcode (Run-действие схемы StoreKit-конфигурацию подхватывает).

