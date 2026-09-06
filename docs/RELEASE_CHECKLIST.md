# Release checklist

State of the build in this worktree, checked against spec section 12 and architecture section 16 on
2026-09-06 with Xcode 26.6 and the iOS 26.5 runtime. Screenshot names refer to the QA run described in
`docs/TEST_PLAN.md`; they are produced by `CorbieUITests` and written to the directory named in
`TEST_RUNNER_CORBIE_SCREENSHOT_DIR`.

Status values: **done**, **blocked on Apple account**, **blocked on device test**, **not done**.

## App Review

| Item | Status | Evidence |
| --- | --- | --- |
| Paywall shows the price | blocked on Apple account | `Corbie/Features/Paywall/PaywallView.swift:141` renders `offer.displayPrice` from StoreKit. `xcodebuild test` runs without a StoreKit configuration, so the automated run sees `paywall.state.unavailable` (screenshot `paywall_top`) and `QAAppearanceUITests.testThePaywallShowsWhatAppReviewLooksFor` skips the price check with that reason. Prices are checked by hand through the Xcode Run action, which does carry `Products.storekit`: `docs/TEST_PLAN.md` section 8. Copy is covered by `CorbieTests/PaywallCopyTests.swift`. |
| Paywall shows the period | blocked on Apple account | Same run limitation. `paywall.offer.monthly` / `paywall.offer.yearly` plus `paywall.offer.permonth`; `CorbieTests/PaywallCopyTests.swift` asserts the yearly plan prints a monthly equivalent. Manual step: `docs/TEST_PLAN.md` section 8 point 3. |
| Paywall shows the auto-renew text | done | `Corbie/Features/Paywall/PaywallView.swift:196` always renders a legal line, `paywall.legal.generic` when no product loaded. `QAAppearanceUITests.testThePaywallShowsWhatAppReviewLooksFor` finds that sentence on screen; `CorbieTests/PaywallCopyTests.swift` asserts the price, the period, the Apple ID, auto-renew and the 24 hour window in the per-product variants. Screenshot `paywall_top`. |
| Paywall has Restore | done | `Corbie/Features/Paywall/PaywallView.swift:186`; asserted live by `QAAppearanceUITests.testThePaywallShowsWhatAppReviewLooksFor`. |
| Paywall links Privacy and Terms | done | `Corbie/Features/Paywall/PaywallView.swift:205`; `CorbieTests/PaywallCopyTests.swift` pins the two https URLs; the same UI test asserts both controls exist. Screenshot `paywall_top`. |
| Sign in with Apple works | blocked on device test | `Corbie/Features/Onboarding/OnboardingIntroView.swift:129`. The simulator has no iCloud account (`AKAuthenticationError -7022` in the test log), so the real flow needs a device with an Apple ID. `docs/TEST_PLAN.md` section 9. |
| The debug bypass is compiled out of Release | done | Both halves sit inside `#if DEBUG`: the button at `Corbie/Features/Onboarding/OnboardingIntroView.swift:139`, the view model entry at `Corbie/Features/Onboarding/OnboardingViewModel.swift:83`. `grep -rn "debugSignIn" Corbie --include='*.swift'` returns only those two files. The UI-test store reset is guarded the same way: `AppEnvironment.bootstrap` calls `eraseEverythingIfRequested()` inside `#if DEBUG` (`Corbie/App/AppEnvironment.swift:120`) and the method itself lives in a `#if DEBUG` extension (`:358`). Proof for the build: `xcodebuild -scheme Corbie -configuration Release -destination 'generic/platform=iOS' build` compiles with none of it. |
| Account deletion exists | done | `Corbie/Features/Settings/SettingsView.swift:259` opens the confirmation, `SettingsViewModel.deleteAccount` (`:134`) deletes or leaves the space, revokes the Apple credential and wipes the device. `QASettingsUITests.testZDeletingTheAccountReturnsToOnboarding` walks it and lands back on onboarding (screenshots `settings_delete_confirm`, `settings_after_delete`). |
| Privacy nutrition labels | not done, App Store Connect only | Nothing to change in the app: analytics carries enum names and counts only (`Packages/CorbieCore/Sources/CorbieCore/Services/AnalyticsEvent.swift`), identified by a device UUID (`AnonymousIdentity`). Answer the questionnaire as spec section 15 says: Data Not Linked to You, Usage Data and Diagnostics. |
| No placeholder text in the app | done | `CorbieTests/QAReleaseTests.swift` (`testNoPlaceholderCopyReachesTheEnglishStrings`) reads the compiled English strings table and fails on `lorem`, `todo`, `fixme`, `placeholder`, `tbd`, `xxx`. |
| No exclamation marks, em dashes or arrows in the copy | done | `CorbieTests/QAReleaseTests.swift` (`testTheEnglishCopyKeepsTheBrandRules`) plus `scripts/lint_style.sh`, which checks every language in the catalog. |
| No third-party SDKs | done | `Packages/CorbieCore/Package.swift` declares no runtime dependency; the only optional package (`swift-testing`) is added for tests when `CORBIE_EXTERNAL_TESTING=1`. |
| App icon | not done, blocker | `Corbie/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` declares one 1024x1024 universal slot and the folder carries no image file. Submission is impossible until the two-raven mark from the brand book is exported into it. `docs/KNOWN_ISSUES.md`. |
| Export compliance | done | `ITSAppUsesNonExemptEncryption` is `false` in `project.yml` (Corbie target info); asserted by `CorbieTests/QAReleaseTests.swift` (`testExportComplianceIsDeclared`). Answer the App Store Connect question as exempt. |
| Age rating | not done, App Store Connect only | 4+ per spec section 12. Nothing in the app produces user-generated public content; capsules and votes stay inside the pair. Fill the questionnaire in App Store Connect. |
| Permission strings match what the app asks for | done | Calendar full access, calendar write-only and photo library are declared and used; location, camera, contacts, Face ID and microphone are not declared and never requested. Asserted by `CorbieTests/QAReleaseTests.swift` (`testEveryPermissionTheAppAsksForHasAReason`, `testNoReasonIsDeclaredForAPermissionTheAppNeverAsksFor`). |
| Permission refusals have no dead end | done | `CorbieUITests/QAPermissionsUITests` walks calendar, photos and notifications with the prompt denied; each screen keeps a way out and the denied ones name where to turn access on. Revoke first with `xcrun simctl privacy`, see `docs/TEST_PLAN.md` section 3. Screenshots `permission_calendar_denied`, `permission_photos_picker`, `permission_notifications_denied`. |
| First launch without network does not crash | done | The whole QA matrix runs against an unreachable server and a simulator with no iCloud account. `CorbieUITests/QAOfflineUITests` walks the invite and the link parser and both fail into a hint with a way out (screenshots `offline_invite_failed`, `offline_parse_failed`). Full table in `docs/TEST_PLAN.md` section 2. |
| Read-only after the trial does not hide data | done | `CorbieUITests/QAReadOnlyUITests` expires the trial through the developer menu: the Tasks plus raises the paywall, the calendar still opens its editor, Today still draws the feed, and the Today checkbox raises the paywall instead of ticking (screenshots `readonly_paywall`, `readonly_calendar_open`, `readonly_today`, `readonly_today_checkbox_paywall`). |
| The weekly recap stays free | done in code, window-bound in the run | `TodayView` wires the recap card with no `premiumGate.require` call (`Corbie/Features/Today/TodayView.swift:139`). `QAReadOnlyUITests.testTheWeeklyRecapStaysFreeAfterTheTrial` proves it when the card is on screen and skips otherwise: `RecapSchedule.window` only opens Sunday 19:00 to Monday 09:00 (`Packages/CorbieCore/Sources/CorbieCore/Services/RecapSummary.swift:64`). |
| Two Apple IDs end to end | blocked on device test | Needs two phones and two Apple IDs; CloudKit sharing between accounts does not work on the simulator. Steps in `docs/TEST_PLAN.md` section 5, including the free-time CloudKit Dashboard privacy audit (5a) and the Today versus OurDay comparison (5b). |
| Sandbox purchases | blocked on Apple account | The two subscriptions have to exist in App Store Connect first. Steps in `docs/TEST_PLAN.md` section 7. |

## Release configuration

| Item | Status | Evidence |
| --- | --- | --- |
| `CORBIE_SERVER_URL` points at the real Supabase project | not done, blocker | The key is read in `Packages/CorbieCore/Sources/CorbieCore/Services/APIClientConfiguration.swift:4` and set nowhere: `grep -rn CORBIE_SERVER_URL --include='*.yml' --include='*.plist' .` finds only the declaration. Every call falls back to `https://corbie.supabase.co/functions/v1` (`:36`). See `docs/KNOWN_ISSUES.md`. |
| CloudKit schema deployed from development to production | blocked on Apple account | Architecture section 18.4. Nothing in the repo can prove it; do it in the CloudKit dashboard before the first TestFlight build that ships to strangers. |
| App Store Server Notifications URL set for sandbox and production | blocked on Apple account | Architecture section 18.9. The server side lives in `server/supabase/functions`. |
| `DEVELOPMENT_TEAM` filled in | blocked on Apple account | `project.yml` ships an empty `DEVELOPMENT_TEAM`. |
| Version and build number | done | `MARKETING_VERSION` 1.0, `CURRENT_PROJECT_VERSION` 1 in `project.yml`; shown in settings through `settings.about.version`. |

## Store listing (spec section 12)

| Item | Status | Evidence |
| --- | --- | --- |
| Name, subtitle, categories, keywords | not done | Copy is written in spec section 12 and has to be typed into App Store Connect. |
| Six screenshots per size | not done | The QA run produces light, dark and Dynamic Type XL captures for three device sizes under the screenshot directory, but they are plain captures, not the angled marketing layout the spec asks for. |
| Preview video, 20 seconds | not done | Nothing recorded. |
| Store listing in five languages | not done, blocker for the localised listing | The app prints raw catalog keys in de, es, fr and it; see `docs/KNOWN_ISSUES.md`. Do not publish localised listings before `scripts/check_translations.sh` passes. |
| Rating prompt after the third joint action, not before day five | not done | `grep -rn "requestReview\|SKStoreReviewController" Corbie Packages/CorbieCore/Sources` returns nothing. Spec section 12 asks for it. |

## Gates before a build goes out

```
scripts/check_strings.sh
scripts/lint_style.sh
scripts/check_translations.sh
cd Packages/CorbieCore && swift build && swift test
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max QA' \
  -derivedDataPath /tmp/corbie-dd-qa build
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max QA' \
  -derivedDataPath /tmp/corbie-dd-qa -only-testing:CorbieTests test
xcrun simctl uninstall "iPhone 17 Pro Max QA" app.corbie
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max QA' \
  -derivedDataPath /tmp/corbie-dd-qa -only-testing:CorbieUITests test
```

`check_translations.sh` is the only one that fails today, and it fails for the localisation blocker in
`docs/KNOWN_ISSUES.md`. The build must produce no `warning:` and no `error:` line.
