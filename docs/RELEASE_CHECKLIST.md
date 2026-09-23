# Release checklist

State of the build, checked against spec section 12 and architecture section 16 on 2026-09-06 and
updated for module 21 (Apple wiring and the monetization flag) on 2026-09-17, with Xcode 26.6 and the
iOS 26.5 runtime. Screenshot names refer to the QA run described in
`docs/TEST_PLAN.md`; they are produced by `CorbieUITests` and written to the directory named in
`TEST_RUNNER_CORBIE_SCREENSHOT_DIR`.

Status values: **done**, **blocked on Apple account**, **blocked on device test**, **not done**.

## App Review

| Item | Status | Evidence |
| --- | --- | --- |
| Paywall shows the price | blocked on device test | `Corbie/Features/Paywall/PlanSelector.swift` renders `displayPrice` from StoreKit for both plans and computes the yearly saving from the monthly price at runtime (`SubscriptionOfferMath`, pinned by `CorbieTests/PaywallScreensTests.swift`). No route was found to give `xcodebuild` the StoreKit configuration (both attempts are in `docs/KNOWN_ISSUES.md`), so the automated run sees `paywall.state.unavailable` (screenshot `paywall_top`) and `QAAppearanceUITests.testThePaywallShowsWhatAppReviewLooksFor` skips the price check with that reason - the one skip in an otherwise green suite. Prices are checked by hand through the Xcode Run action, which does carry `Products.storekit`: `docs/TEST_PLAN.md` section 8. Copy is covered by `CorbieTests/PaywallCopyTests.swift`. |
| Paywall shows the period | blocked on device test | Same run limitation. `paywall.offer.monthly` / `paywall.offer.yearly` plus `paywall.offer.permonth`; `CorbieTests/PaywallCopyTests.swift` asserts the yearly plan prints a monthly equivalent. Manual step: `docs/TEST_PLAN.md` section 8 point 3. |
| Paywall shows the auto-renew text | done | `Corbie/Features/Paywall/PaywallCheckout.swift` always renders a legal line under the CTA, `paywall.legal.generic` when no product loaded. `QAAppearanceUITests.testThePaywallShowsWhatAppReviewLooksFor` finds that sentence on screen; `CorbieTests/PaywallCopyTests.swift` asserts the price, the period, the Apple ID, auto-renew and the 24 hour window in the per-product variants. Screenshot `paywall_top`. |
| Paywall has Restore | done | `Corbie/Features/Paywall/PaywallCheckout.swift` (`paywall.action.restore`); asserted live by `QAAppearanceUITests.testThePaywallShowsWhatAppReviewLooksFor`. |
| Paywall links Privacy and Terms | done | `Corbie/Features/Paywall/PaywallCheckout.swift`; `CorbieTests/PaywallCopyTests.swift` pins the two https URLs; the same UI test asserts both controls exist. Screenshot `paywall_top`. |
| Sign in with Apple works | blocked on device test | `Corbie/Features/Onboarding/OnboardingIntroView.swift:132`. The simulator has no iCloud account (`AKAuthenticationError -7022` in the test log), so the real flow needs a device with an Apple ID. `docs/TEST_PLAN.md` section 9. |
| The debug bypass is compiled out of Release | done | Both halves sit inside `#if DEBUG`: the row in the stack at `Corbie/Features/Onboarding/OnboardingIntroView.swift:21`, the button itself at `:144`, the view model entry at `Corbie/Features/Onboarding/OnboardingViewModel.swift:83`. `grep -rn "debugSignIn" Corbie --include='*.swift'` returns only those two files. The UI-test store reset is guarded the same way: `CorbieApp.init` calls `DebugLaunch.resetStoreIfRequested()` inside `#if DEBUG` (`Corbie/App/CorbieApp.swift:16`) and the whole of `Corbie/App/DebugLaunch.swift` sits inside `#if DEBUG`. So is the developer menu that expires the trial: `Corbie/Features/Settings/SettingsView.swift:274` (`#if DEBUG`, the link at `:275`) and all of `Corbie/Features/Paywall/DebugMenuView.swift`. Proof from the built product, not from the source: `xcodebuild -scheme Corbie -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/corbie-dd-release build` succeeds, and the binary it writes carries no `debugSignIn` symbol, no `-corbie-reset-store` string, no "Expire the trial" and no "debug build" (`nm -a` and `strings` over `Release-iphonesimulator/Corbie.app/Corbie`, four counts of zero). |
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
| Sandbox purchases | blocked on Apple account | The two subscriptions have to exist in App Store Connect first. Steps in `docs/TEST_PLAN.md` section 7. |
| 14 day introductory offer on both products | not done, App Store Connect only | `Products.storekit` carries a `P2W` free introductory offer on `app.corbie.monthly` and `app.corbie.yearly`, which only steers the local test configuration. The same offer has to be created on both products in App Store Connect, or `Product.SubscriptionInfo.isEligibleForIntroOffer` answers false in production and the CTA reads Subscribe for everyone. |
| Billing Grace Period switched on | not done, App Store Connect only | A console setting, not code. Without it Apple never sends `DID_FAIL_TO_RENEW` with a grace window, so `in_grace_period` never reaches `entitlements` and a failed renewal drops the pair to read-only on the first retry. |

## Module 21 gates for a free v1

| Item | Status | Evidence |
| --- | --- | --- |
| Monetization is off on the live server | release gate | `curl -s https://powtuiqqagdoiuqjeebr.supabase.co/functions/v1/config` must print `{"monetizationEnabled":false}` on the day of submission. The app then treats everyone as premium: no trial offer, no comparison table, no read-only, widgets unlocked, no trial notice, no subscription section in settings (`NetMonetizationTests`, `MonetizationOffUITests`). |
| Purchase path unreachable while monetization is off | done | `PremiumGate.presentPaywall` returns early and every gated action passes; `TrialOfferView` is only shown by `RootView.offerTheTrialOnce`, which does not even claim its one-time flag while monetization is off. `StoreService` never loads products because `EntitlementService.refresh` returns before it asks StoreKit. `Products.storekit` is a navigator file group and a scheme Run option, not a bundle resource. Do not submit the two subscriptions with this version. |
| Universal links on `yourcorbie.app` | done | `Configs/Corbie.entitlements` carries `applinks:yourcorbie.app`; the live association file names `735XXP9B5R.app.corbie` for `/join/*`, is served as `application/json`, and Apple's CDN (`app-site-association.cdn-apple.com/a/v1/yourcorbie.app`) already holds the same body. |
| Support and privacy URLs | done | `https://yourcorbie.app/support`, `/privacy` and `/terms` answer 200. The app opens `/privacy` and `/terms` from settings and the paywall footer (`LegalPage`), and settings has a Contact support entry that mails `support@yourcorbie.app` with the device, system and app version prefilled (`SupportMail`). |
| Privacy manifest in every target | done | `Corbie/Resources/PrivacyInfo.xcprivacy`, `CorbieWidgets/PrivacyInfo.xcprivacy`, `CorbieShare/PrivacyInfo.xcprivacy`: App Group defaults declared with reasons 1C8F.1 and CA92.1. Without it App Store Connect rejects the upload with ITMS-91053. |
| No personal address anywhere | done in the app, not in git | No personal address in the sources, the string catalog or the built binary; `SupportMailTests.testTheOnlyAddressInTheCatalogIsSupport` pins it. The public GitHub repository still shows the personal address as the author of every commit. |
| Trader status (EU Digital Services Act) | founder, App Store Connect | See the module 21 report. |

## When banking lands

1. Sign the Paid Apps Agreement (bank account and tax form) in App Store Connect, Business.
2. Create `app.corbie.monthly` and `app.corbie.yearly` in the group `corbie.premium` with the prices from spec section 8. On both, add a 14-day free introductory offer. Turn on Billing Grace Period for the group.
3. Decide how production App Store notifications reach a project whose `APPLE_ENV` says `Production`: either a second Supabase project for production with its own URL in App Store Connect, or a server change that accepts both environments on one project and records which one wrote each row. The function refuses the other environment today, and both URLs point at the one project.
4. Set `APPLE_TEAM_ID`, `APPLE_KEY_ID` and `APPLE_PRIVATE_KEY` if that has not happened yet; `/apple-revoke` needs them either way.
5. Submit the two subscriptions for review together with a build.
6. Run the sandbox purchase checks in `docs/TEST_PLAN.md` section 7 on a build with `-corbie-monetization on` or the developer menu's "Force monetization on".
7. Flip the value in the Supabase SQL editor:
   `update public.app_config set value = 'true'::jsonb, updated_at = now() where key = 'monetization_enabled';`
8. Verify: `curl -s https://powtuiqqagdoiuqjeebr.supabase.co/functions/v1/config` prints `{"monetizationEnabled":true}`. On a device that installed during the free period, relaunch the app: the trial offer appears once, the plus in Tasks opens the comparison table after the offer is skipped, and settings shows the subscription section.
9. To undo, run the same statement with `'false'::jsonb`. Devices pick it up on the next launch, foreground or hourly refresh.

## Release configuration

| Item | Status | Evidence |
| --- | --- | --- |
| The app builds in the Release configuration | done, was failing | Two `#Preview` blocks called `AppEnvironment.preview()` and `AppEnvironment.previewSignedIn()`, which live in a `#if DEBUG` extension, without a guard of their own, so `-configuration Release` failed to compile `OnboardingIntroView.swift` and `SettingsView.swift` and no archive was possible. Both are wrapped now and the Release build succeeds with no `warning:` and no `error:` line. It was broken on `main` too: `git show main:Corbie/Features/Settings/SettingsView.swift` ends with the same unguarded preview. |
| `CORBIE_SERVER_URL` points at the real Supabase project | done | `project.yml` base settings carry the project ref `powtuiqqagdoiuqjeebr`; the built `Corbie.app/Info.plist` shows it, and the live smoke run in `server/DEPLOY.md` section 7 passed 15 of 15 non-Apple checks. Deployment steps and secrets are in `server/DEPLOY.md`. |
| CloudKit schema deployed from development to production | blocked on Apple account | Architecture section 18.4. Nothing in the repo can prove it; do it in the CloudKit dashboard before the first TestFlight build that ships to strangers. |
| App Store Server Notifications URL set for sandbox and production | done, with a known gap | Both point at `https://powtuiqqagdoiuqjeebr.supabase.co/functions/v1/appstore-notifications`. One project answers both, but `APPLE_ENV` is `Sandbox`, so production notifications are refused with 400 and Apple keeps retrying. Harmless while monetization is off and no product is on sale; it has to be solved before the flip, see "When banking lands". |
| `DEVELOPMENT_TEAM` filled in | done | `project.yml` base settings carry `735XXP9B5R`. Signing needs that team signed into Xcode on this Mac (Settings, Accounts); see the module 21 report for the device build result. |
| Version and build number | done | `MARKETING_VERSION` 1.0, `CURRENT_PROJECT_VERSION` 1 in `project.yml`; shown in settings through `settings.about.version`. |

## Store listing (spec section 12)

| Item | Status | Evidence |
| --- | --- | --- |
| Name, subtitle, categories, keywords | not done | Copy is written in spec section 12 and has to be typed into App Store Connect. |
| Six screenshots per size | not done | The QA run produces light, dark and Dynamic Type XL captures for three device sizes under the screenshot directory, but they are plain captures, not the angled marketing layout the spec asks for. |
| Preview video, 20 seconds | not done | Nothing recorded. |
| Store listing in five languages | not done, App Store Connect only | The app itself is translated: `scripts/check_translations.sh` passes, and `CorbieUITests/LocalizationUITests` walks onboarding, the five tabs, both Plans segments and the Us hub in de, es, fr and it with every label written out in that language (screenshots under `<pass>/de`, `/es`, `/fr`, `/it`). The listing copy still has to be written and typed into App Store Connect. |
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
