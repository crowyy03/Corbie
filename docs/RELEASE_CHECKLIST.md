# Release checklist

State of the build, checked against spec section 12 and architecture section 16 on 2026-09-06,
updated for module 21 (Apple wiring and the monetization flag) on 2026-09-17 and for a v1 that is
paid from day one on 2026-09-25, with Xcode 26.6 and the iOS 26.5 runtime. Screenshot names refer to the QA run described in
`docs/TEST_PLAN.md`; they are produced by `CorbieUITests` and written to the directory named in
`TEST_RUNNER_CORBIE_SCREENSHOT_DIR`.

Status values: **done**, **blocked on Apple account**, **blocked on device test**, **not done**.

## App Review

| Item | Status | Evidence |
| --- | --- | --- |
| Paywall shows the price | blocked on device test | `Corbie/Features/Paywall/PlanSelector.swift` renders `displayPrice` from StoreKit for both plans and computes the yearly saving from the monthly price at runtime (`SubscriptionOfferMath`, pinned by `CorbieTests/PaywallScreensTests.swift`). No route was found to give `xcodebuild` the StoreKit configuration (both attempts are in `docs/KNOWN_ISSUES.md`), so the automated run sees `paywall.state.unavailable` (screenshot `paywall_top`) and `QAAppearanceUITests.testThePaywallShowsWhatAppReviewLooksFor` skips the price check with that reason - the one skip in an otherwise green suite. Prices are checked by hand through the Xcode Run action, which does carry `Products.storekit`: `docs/TEST_PLAN.md` section 8. Copy is covered by `CorbieTests/PaywallCopyTests.swift`. |
| Paywall shows the period | blocked on device test | Same run limitation. `paywall.offer.monthly` / `paywall.offer.yearly` plus `paywall.offer.permonth`; `CorbieTests/PaywallCopyTests.swift` asserts the yearly plan prints a monthly equivalent. Manual step: `docs/TEST_PLAN.md` section 8 point 3. |
| Paywall shows the auto-renew text | done | `Corbie/Features/Paywall/PaywallCheckout.swift` always renders a legal line under the CTA, `paywall.legal.generic` when no product loaded. `QAAppearanceUITests.testThePaywallShowsWhatAppReviewLooksFor` finds that sentence on screen; `CorbieTests/PaywallCopyTests.swift` asserts the price, the period, the Apple ID, auto-renew and the 24 hour window in the per-product variants. Screenshot `paywall_top`. |
| A reviewer's sandbox purchase unlocks the production-signed build | done in code, not seen under review | App Review buys in the sandbox from the production-signed build, and Apple does not document what `AppTransaction.environment` reports there, so both answers are handled: the device's own StoreKit transactions count whatever their environment, `POST /entitlement/sync` stores a sandbox transaction under Sandbox instead of refusing it, and the widgets and the notification and widget actions follow this device's own resolution when its environment matches their own. Pinned by `NetEntitlementServiceTests.aReviewersSandboxPurchaseUnlocksWhateverEnvironmentTheReviewBuildReports` (production, sandbox and missing proof), `DomainWidgetPremiumTests`/`theWidgetsAndIntentsFollowThisDevicesOwnPurchaseOnlyInTheSameEnvironment` and the server test "a reviewer's sandbox purchase from a production-signed build is kept in Sandbox and never answers Production". The other half, that a sandbox purchase never reaches an App Store customer, is `aSandboxPurchaseNeverReachesARealAppStoreCustomer`. `docs/DECISIONS.md` 2026-09-25. |
| Paywall has Restore | done | `Corbie/Features/Paywall/PaywallCheckout.swift` (`paywall.action.restore`); asserted live by `QAAppearanceUITests.testThePaywallShowsWhatAppReviewLooksFor`. |
| Paywall links Privacy and Terms | done | `Corbie/Features/Paywall/PaywallCheckout.swift`; `CorbieTests/PaywallCopyTests.swift` pins the two https URLs; the same UI test asserts both controls exist. Screenshot `paywall_top`. |
| Sign in with Apple works | blocked on device test | `Corbie/Features/Onboarding/OnboardingIntroView.swift:132`. The simulator has no iCloud account (`AKAuthenticationError -7022` in the test log), so the real flow needs a device with an Apple ID. `docs/TEST_PLAN.md` section 9. |
| The debug bypass and the developer menu are compiled out of Release | done, checked on every Release build | Everything developer-only sits inside `#if DEBUG`: the Developer row (`Corbie/Features/Settings/SettingsView.swift:349`), all of `DebugMenuView.swift`, `DebugNotificationsSections.swift` and `DebugLaunch.swift` (the `-corbie-*` launch arguments), the debug sign-in (`OnboardingIntroView.swift` `debugSignInButton`, `OnboardingViewModel.debugSignIn`), and the entitlement and monetization overrides in `CorbieCore/Services/PremiumGateDebug.swift` with their readers. The last build phase of the Corbie target, "Check Release carries no debug-only code", runs `scripts/scan_debug_markers.sh` on every non-Debug build and Archive: 51 markers, the 27 of screenshot mode plus 24 of the developer tools (type names, launch arguments, override keys, the longer row titles and the two former catalog keys). On 2026-09-26 the scan found `settings.developer` and `onboarding.debug.signin` with their English text in the `.strings` files of all three bundles of a Release archive: the two debug labels were catalog keys, so their text shipped while the code did not. Both are `Text(verbatim:)` now and gone from the catalog; the next archive scanned clean. |
| Account deletion exists | done | `Corbie/Features/Settings/SettingsView.swift:259` opens the confirmation, `SettingsViewModel.deleteAccount` (`:134`) deletes or leaves the space, revokes the Apple credential and wipes the device. `QASettingsUITests.testZDeletingTheAccountReturnsToOnboarding` walks it and lands back on onboarding (screenshots `settings_delete_confirm`, `settings_after_delete`). |
| Privacy nutrition labels | done in App Store Connect, one mismatch | Published: Product Interaction for analytics, Crash and Performance for app functionality, nothing linked, no tracking. The code collects no crash or performance data (no MetricKit, no crash reporter), so that line over-declares; it also leaves out Other User Content, which the app does send (links pasted for wishes go to `/parse`, invite share links go to `/invite`). `Corbie/Resources/PrivacyInfo.xcprivacy` declares exactly what the code does. Align the label with it. |
| No placeholder text in the app | done | `CorbieTests/QAReleaseTests.swift` (`testNoPlaceholderCopyReachesTheEnglishStrings`) reads the compiled English strings table and fails on `lorem`, `todo`, `fixme`, `placeholder`, `tbd`, `xxx`. |
| No exclamation marks, em dashes or arrows in the copy | done | `CorbieTests/QAReleaseTests.swift` (`testTheEnglishCopyKeepsTheBrandRules`) plus `scripts/lint_style.sh`, which checks every language in the catalog. |
| No third-party SDKs | done | `Packages/CorbieCore/Package.swift` declares no runtime dependency; the only optional package (`swift-testing`) is added for tests when `CORBIE_EXTERNAL_TESTING=1`. |
| App icon | done | `Corbie/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png`, the two-raven mark from the brand book, 1024x1024. The same outline is drawn in the app by `CorbieMarkShape` (`Packages/CorbieCore/Sources/CorbieCore/Design/CorbieMarkShape.swift`), so the icon and the in-app mark are the same drawing rather than two lookalikes. |
| Export compliance | done | `ITSAppUsesNonExemptEncryption` is `false` in `project.yml` (Corbie target info); asserted by `CorbieTests/QAReleaseTests.swift` (`testExportComplianceIsDeclared`). Answer the App Store Connect question as exempt. |
| Age rating | done in App Store Connect | 4+, set by the founder. Nothing in the app produces public user content; capsules and votes stay inside the pair. |
| Permission strings match what the app asks for | done | Calendar full access, calendar write-only and photo library are declared and used; location, camera, contacts, Face ID and microphone are not declared and never requested. Asserted by `CorbieTests/QAReleaseTests.swift` (`testEveryPermissionTheAppAsksForHasAReason`, `testNoReasonIsDeclaredForAPermissionTheAppNeverAsksFor`). |
| Permission refusals have no dead end | done | `CorbieUITests/QAPermissionsUITests` walks calendar, photos and notifications with the prompt denied; each screen keeps a way out and the denied ones name where to turn access on. Revoke first with `xcrun simctl privacy`, see `docs/TEST_PLAN.md` section 3. Screenshots `permission_calendar_denied`, `permission_photos_picker`, `permission_notifications_denied`. |
| First launch without network does not crash | done | The whole QA matrix runs against an unreachable server and a simulator with no iCloud account. `CorbieUITests/QAOfflineUITests` walks the invite and the link parser and both fail into a hint with a way out (screenshots `offline_invite_failed`, `offline_parse_failed`). Full table in `docs/TEST_PLAN.md` section 2. |
| Read-only after the trial does not hide data | done | `CorbieUITests/QAReadOnlyUITests` expires the trial through the developer menu: the Tasks plus raises the paywall, the calendar still opens its editor, Today still draws the feed, and the Today checkbox raises the paywall instead of ticking (screenshots `readonly_paywall`, `readonly_calendar_open`, `readonly_today`, `readonly_today_checkbox_paywall`). |
| The weekly recap stays free | done | `TodayView` wires the recap card with no `premiumGate.require` call. `QAReadOnlyUITests.testTheWeeklyRecapStaysFreeAfterTheTrial` expires the trial, opens the card and checks no paywall follows. The 2026-09-06 run fell inside the card's window (Sunday 19:00 to Monday 09:00, `Packages/CorbieCore/Sources/CorbieCore/Services/RecapSummary.swift:64`), so the test ran rather than skipped on all three devices; screenshot `readonly_recap_card`. Outside that window it skips itself. |
| Two Apple IDs end to end | blocked on device test | Needs two phones and two Apple IDs; CloudKit sharing between accounts does not work on the simulator. Steps in `docs/TEST_PLAN.md` section 5, including the free-time CloudKit Dashboard privacy audit (5a) and the Today versus OurDay comparison (5b). |
| Sandbox purchases | blocked on Apple account | Needs App Store Connect steps 1 to 9 below. Then the founder's checklist in `docs/TEST_PLAN.md` section 7, on two phones, with the SQL that reads the server's row for each step. |
| 14 day introductory offer on both products | not done, App Store Connect only | `Products.storekit` carries a `P2W` free introductory offer on `app.corbie.monthly` and `app.corbie.yearly`, which only steers the local test configuration. The same offer has to be created on both products in App Store Connect (step 4 below). Without it the product carries no introductory offer, `StoreService` promises no trial and the button reads Subscribe for everyone. It is the missing offer that does this, not the eligibility check: Apple says `isEligibleForIntroOffer` can answer true even when no offer is set up. |
| Billing Grace Period switched on | not done, App Store Connect only | Step 6 below. Without it a failed renewal goes straight to billing retry and the pair to read-only. |
| Terms of Use and Privacy Policy in the metadata | done in the listings, App Store Connect by hand | Apple asks both links in the metadata of an app with subscriptions. Every `docs/store/*.md` description ends with `Terms: https://yourcorbie.app/terms` and `Privacy: https://yourcorbie.app/privacy`; the License Agreement and the Privacy Policy URL fields are step 8 below. |

## Launch gates, paid from day one

| Item | Status | Evidence |
| --- | --- | --- |
| The monetization flag counts as on until the server says otherwise | done in code | `MonetizationFlagStore.isEnabled` falls back to on when `/config` was never fetched (`Packages/CorbieCore/Sources/CorbieCore/Services/MonetizationFlag.swift`), and `/config` answers true when `app_config` has no row (`server/supabase/functions/config/index.ts`). A first launch offline is read-only with the trial offer, not free. People who pay are not affected: their access comes from their own StoreKit transaction. No migration touches the live row; it still says false, so the test phones that fetched it stay free until step 12 below. |
| The subscriptions ship with the build | App Store Connect, founder | Both subscriptions are submitted for review together with the version (step 10 below). Apple reviews the first subscriptions of an app only with a new version. |
| Universal links on `yourcorbie.app` | done | `Configs/Corbie.entitlements` carries `applinks:yourcorbie.app`; the live association file names `735XXP9B5R.app.corbie` for `/join/*`, is served as `application/json`, and Apple's CDN (`app-site-association.cdn-apple.com/a/v1/yourcorbie.app`) already holds the same body. |
| Support and privacy URLs | done | `https://yourcorbie.app/support`, `/privacy` and `/terms` answer 200. The app opens `/privacy` and `/terms` from settings and the paywall footer (`LegalPage`), and settings has a Contact support entry that mails `support@yourcorbie.app` with the device, system and app version prefilled (`SupportMail`). |
| Privacy manifest in every target | done | `Corbie/Resources/PrivacyInfo.xcprivacy`, `CorbieWidgets/PrivacyInfo.xcprivacy`, `CorbieShare/PrivacyInfo.xcprivacy`: App Group defaults declared with reasons 1C8F.1 and CA92.1. Without it App Store Connect rejects the upload with ITMS-91053. |
| No personal address anywhere | done in the app, not in git | No personal address in the sources, the string catalog or the built binary; `SupportMailTests.testTheOnlyAddressInTheCatalogIsSupport` pins it. The public GitHub repository still shows the personal address as the author of every commit. |
| Trader status (EU Digital Services Act) | founder, App Store Connect | See the module 21 report. |

## App Store Connect before submission

In this order; steps 1 to 9 are also what the sandbox checklist in `docs/TEST_PLAN.md` section 7
needs.

1. Business: sign the Paid Apps Agreement (bank account and tax forms). Nothing can be sold or
   tested in the sandbox before it is active.
2. The Corbie app, Monetization, Subscriptions: create the group with the reference name
   `Corbie Premium`. Add its display name in five localizations, English, German, Spanish, French
   and Italian: `Corbie Premium` in all five.
3. In that group create two subscriptions, both on the same level:

   | Reference name | Product ID | Duration | Price |
   | --- | --- | --- | --- |
   | Corbie Monthly | `app.corbie.monthly` | 1 month | $4.99 |
   | Corbie Yearly | `app.corbie.yearly` | 1 year | $29.99 |

   Set the price with the United States as the base country and keep Apple's automatic prices for
   every other storefront; do not set any storefront by hand. Availability: the same countries as
   the app. Give each one a display name and a description in the same five languages:

   | Language | Monthly name | Monthly description | Yearly name | Yearly description |
   | --- | --- | --- | --- | --- |
   | English | Monthly | Everything in Corbie for two, every month. | Yearly | Everything in Corbie for two, once a year. |
   | German | Monatlich | Alles in Corbie für euch zwei, monatlich. | Jährlich | Alles in Corbie für euch zwei, jährlich. |
   | Spanish | Mensual | Todo Corbie para los dos, cada mes. | Anual | Todo Corbie para los dos, una vez al año. |
   | French | Mensuel | Tout Corbie pour vous deux, chaque mois. | Annuel | Tout Corbie pour vous deux, une fois par an. |
   | Italian | Mensile | Tutto Corbie per voi due, ogni mese. | Annuale | Tutto Corbie per voi due, una volta l'anno. |

   The descriptions stay under 45 characters and the names under 30, the limits I remember from the
   form; Apple's help pages I read do not state them, so trust the counter on the page. Each
   subscription also needs a review screenshot of the paywall (`docs/TEST_PLAN.md` section 8).
4. On both subscriptions, Subscription Prices, the add button, Create Introductory Offer: all
   countries, starts now with no end date, Free, duration 2 weeks.
5. App Information, App Store Server Notifications: Version 2 for both, Production Server URL and
   Sandbox Server URL both
   `https://powtuiqqagdoiuqjeebr.supabase.co/functions/v1/appstore-notifications`. One function
   serves both environments and stores their rows apart, by the environment inside each signed
   notification.
6. Subscriptions, Billing Grace Period, Set Up Billing Grace Period: 16 days, Only Paid to Paid
   Renewals, Production and Sandbox Environment. Apple offers 3, 16 or 28 days. My pick is 16:
   3 days rarely covers a card being replaced, and paid to paid keeps someone whose card fails at
   the end of the free trial from getting weeks more for free. Change it if you see it otherwise.
7. Users and Access, Integrations, under Keys In-App Purchase, Generate In-App Purchase Key.
   Download the `.p8` file (Apple lets you download it once) and note the Key ID, and the Issuer ID
   shown above the key list. Then in the
   Supabase dashboard, Edge Functions, Secrets, add four secrets:

   | Name | Value |
   | --- | --- |
   | `APPSTORE_ISSUER_ID` | the Issuer ID from the In-App Purchase keys page |
   | `APPSTORE_KEY_ID` | the Key ID of the new key |
   | `APPSTORE_PRIVATE_KEY` | the whole `.p8` file, including the BEGIN and END lines |
   | `APPSTORE_APP_APPLE_ID` | `6812410537` (not secret, the app's Apple ID from App Information) |

   Paste the private key in the dashboard, not with `supabase secrets set`, so it stays out of the
   shell history.
8. App Information: License Agreement, keep Apple's standard EULA or paste the Terms of Use;
   Privacy Policy URL `https://yourcorbie.app/privacy`. In each of the five localizations of the
   version page paste the description from `docs/store/<language>.md`; it already ends with the
   Terms and Privacy lines.
9. Run the manual deploy job (see Release configuration, "Database migrations"): it pushes
   migrations 0009 and 0010 and deploys the functions back to back, which matters because the functions
   deployed before 0009 answer `500` once it runs, and `invite` deployed before 0010 cannot insert a
   code. Without `SUPABASE_ACCESS_TOKEN` do the same by
   hand, `server/DEPLOY.md` steps 3 and 4. Check `select count(*) from public.subscriptions;`
   answers in the SQL editor, then delete the unused `APPLE_ENV` secret.
10. Submit both subscriptions for review together with the build: on the version page, In-App
    Purchases and Subscriptions, select both.
11. Before the build goes out, run `docs/TEST_PLAN.md` section 7 on a TestFlight build and a Debug
    build.
12. At launch, flip the flag in the Supabase SQL editor:
    `update public.app_config set value = 'true'::jsonb, updated_at = now() where key = 'monetization_enabled';`
13. Verify: `curl -s https://powtuiqqagdoiuqjeebr.supabase.co/functions/v1/config` prints
    `{"monetizationEnabled":true}`. On a test phone that fetched false before, relaunch the app:
    the trial offer appears once, the plus in Tasks opens the comparison table after the offer is
    skipped, and settings shows the subscription section.

To undo step 12, run the same statement with `'false'::jsonb`. Devices pick it up on the next
launch, foreground or hourly refresh.

## Release configuration

| Item | Status | Evidence |
| --- | --- | --- |
| The app builds in the Release configuration | done, was failing | Two `#Preview` blocks called `AppEnvironment.preview()` and `AppEnvironment.previewSignedIn()`, which live in a `#if DEBUG` extension, without a guard of their own, so `-configuration Release` failed to compile `OnboardingIntroView.swift` and `SettingsView.swift` and no archive was possible. Both are wrapped now and the Release build succeeds with no `warning:` and no `error:` line. It was broken on `main` too: `git show main:Corbie/Features/Settings/SettingsView.swift` ends with the same unguarded preview. |
| `CORBIE_SERVER_URL` points at the real Supabase project | done | `project.yml` base settings carry the project ref `powtuiqqagdoiuqjeebr`; the built `Corbie.app/Info.plist` shows it, and the live smoke run in `server/DEPLOY.md` section 7 passed 15 of 15 non-Apple checks. Deployment steps and secrets are in `server/DEPLOY.md`. |
| CloudKit schema deployed from development to production | blocked on Apple account | Architecture section 18.4. Nothing in the repo can prove it; do it in the CloudKit dashboard before the first TestFlight build that ships to strangers. **Until it is deployed, no Release build goes on a phone**: not TestFlight, not an Archive, not a Profile or Release run from Xcode. Since 2026-09-26 the environment follows the build configuration (`CORBIE_CLOUDKIT_ENVIRONMENT`), so every Release build writes to Production, where the `CD_` record types do not exist yet. Debug runs from Xcode stay on Development. |
| App Store Server Notifications URL set for sandbox and production | done, check with step 5 above | Both point at `https://powtuiqqagdoiuqjeebr.supabase.co/functions/v1/appstore-notifications`. The function takes the environment from the signed notification and keeps Sandbox and Production rows apart, so a sandbox purchase never grants or extends production access. Version 2 has to be selected for both. |
| Database migrations | manual from this batch on | Migrations reach the production database only when someone runs the manual job in GitHub Actions; a push to `main` no longer applies them. Until `SUPABASE_ACCESS_TOKEN` is set in the repository secrets, CI deploys nothing at all and the manual job stops with an error saying so. Steps: `server/DEPLOY.md` section 8. |
| `DEVELOPMENT_TEAM` filled in | done | `project.yml` base settings carry `735XXP9B5R`. Signing needs that team signed into Xcode on this Mac (Settings, Accounts); see the module 21 report for the device build result. |
| Version and build number | done | `MARKETING_VERSION` 1.0, `CURRENT_PROJECT_VERSION` 1 in `project.yml`; shown in settings through `settings.about.version`. |
| Screenshot mode is compiled out of Release | done | Every screenshot-mode type, file, key and launch argument carries `ScreenshotMode`, `screenshotMode` or `screenshot-mode` and sits inside `#if DEBUG` (app, CorbieCore; the widgets and the share extension have no code of their own for it). `scripts/scan_debug_markers.sh <app>` fails if any of 27 markers (the three spellings, `DemoAssets`, Alex, Nora, the demo task, wish, plan and capsule titles, the demo image names, two phrases from the demo answers) shows up in `strings -a` or `nm -a` of a Mach-O in the bundle (app, both extensions), in the bytes of any file in the bundle as UTF-8 or UTF-16 (compiled `.strings` are binary plists that keep non-ASCII text as UTF-16), or in a file name. The Corbie target runs it as its last build phase, after the extensions are embedded, in every configuration except Debug, so every Release build and every Archive fails on a leak. `scripts/check_release_debug_code.sh` builds Release for the generic iOS Simulator into `/tmp/corbie-dd-release-check`, checks that the build log shows the phase passing and runs the scan again. On 2026-09-24: ok, 3 binaries and 108 files clean. A copy of that Release app with an added `.strings` file holding a demo title, a `.json` file holding a task title and a binary plist holding a UTF-16 marker fails the scan. Swift keeps string literals of up to 15 bytes inside the instructions, so "Alex" and "Nora" would not show up even if the code were there; the type names and the longer titles are what catch leaked code. The Debug side is pinned by `CorbieTests/ScreenshotModeTests.swift` (`ScreenshotModeDebugBuildTests`, compiled, not run yet): the Debug app binaries carry `ScreenshotModeSwitch`, `-corbie-screenshot-mode` and "Noise-cancelling headphones", the widget extension carries `ScreenshotMode`, so the pair shows the boundary is `#if DEBUG`. The demo photos in `DemoAssets/` reach the bundle only through a build phase that exits unless `CONFIGURATION` is Debug. |

## Store listing (spec section 12)

| Item | Status | Evidence |
| --- | --- | --- |
| Name, subtitle, categories, keywords | not done | Copy is written in spec section 12 and has to be typed into App Store Connect. |
| Six screenshots per size | not done | The QA run produces light, dark and Dynamic Type XL captures for three device sizes under the screenshot directory, but they are plain captures, not the angled marketing layout the spec asks for. |
| Preview video, 20 seconds | not done | Nothing recorded. |
| Store listing in five languages | written, App Store Connect by hand | The app itself is translated: `scripts/check_translations.sh` passes, and `CorbieUITests/LocalizationUITests` walks onboarding, the five tabs, both Plans segments and the Us hub in de, es, fr and it with every label written out in that language (screenshots under `<pass>/de`, `/es`, `/fr`, `/it`). The listing copy is in `docs/store/*.md`, with no amounts and the terms of the subscription only, and has to be pasted into App Store Connect (step 8 above). |
| Rating prompt after the third joint action, not before day five | done | `ReviewPromptTracker` (Packages/CorbieCore/Sources/CorbieCore/Services/ReviewPromptTracker.swift) counts partner-authored change batches through `RemoteChangeNotifier.handle`, records the install date on first launch, and `RootView.askForReviewIfEarned` calls `requestReview` once when the count reaches 3 and 5 days have passed; rules pinned by `DomainReviewPromptTests`. |

## Gates before a build goes out

```
scripts/check_strings.sh
scripts/lint_style.sh
scripts/check_translations.sh
cd Packages/CorbieCore && swift build && swift test
cd server && deno test -A
xcrun simctl create "iPhone 17 Pro Max QA" "iPhone 17 Pro Max"
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max QA' \
  -derivedDataPath /tmp/corbie-dd-qa build
xcodebuild -scheme Corbie -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/corbie-dd-release build
scripts/check_release_debug_code.sh
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max QA' \
  -derivedDataPath /tmp/corbie-dd-qa -only-testing:CorbieTests test
xcrun simctl uninstall "iPhone 17 Pro Max QA" app.corbie
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max QA' \
  -derivedDataPath /tmp/corbie-dd-qa -only-testing:CorbieUITests test
xcrun simctl delete "iPhone 17 Pro Max QA"
```

On 2026-09-09 that reads: four gates ok (`check_colors.sh` joined the list with the theme engine), 579 core tests, 112 server
tests, both builds succeeded, 310 app tests, and the UI suite at 45 tests with 2 skips: the full run
turned up one failure in the paywall walk, caused by the launch helper closing the trial offer that
the walk wanted to see; after moving that step the walk and two helper-based walks were rerun green. The
Release build belongs in the list because it is the one that broke without anyone noticing.

All three gates pass. The build must produce no `warning:` and no `error:` line, and it does: the only
line matching either word in a `build-for-testing` log comes from `appintentsmetadataprocessor`
reporting that the UI test runner has no AppIntents framework, and a plain `build` does not print it
at all.
