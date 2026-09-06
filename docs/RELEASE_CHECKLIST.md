# Release checklist

State of the build in this worktree, checked against spec section 12 and architecture section 16 on 2026-09-06.
Screenshot names refer to the QA run described in `docs/TEST_PLAN.md`; they are produced by
`CorbieUITests` and written to the directory named in `TEST_RUNNER_CORBIE_SCREENSHOT_DIR`.

Status values: **done**, **blocked on Apple account**, **blocked on device test**, **not done**.

## App Review

| Item | Status | Evidence |
| --- | --- | --- |
| Paywall shows the price | blocked on Apple account | `Corbie/Features/Paywall/PaywallView.swift:141` renders `offer.displayPrice`; the price comes from StoreKit, so a simulator without a StoreKit configuration on the test action shows `paywall.state.unavailable` instead (screenshot `readonly_paywall`). Copy is covered by `CorbieTests/PaywallCopyTests.swift:57`. |
| Paywall shows the period | done | `paywall.offer.monthly` / `paywall.offer.yearly` plus `paywall.offer.permonth`; `CorbieTests/PaywallCopyTests.swift:57` asserts the yearly plan prints a monthly equivalent. |
| Paywall shows the auto-renew text | done | `Corbie/Features/Paywall/PaywallView.swift:196` always renders a legal line, `paywall.legal.generic` when no product loaded; `CorbieTests/PaywallCopyTests.swift:65` and `:75` assert the price, the period, the Apple ID, auto-renew and the 24 hour window. Screenshot `readonly_paywall`. |
| Paywall has Restore | done | `Corbie/Features/Paywall/PaywallView.swift:186`; asserted live by `CorbieUITests/QAAppearanceUITests.swift` (`testPaywallTour`). |
| Paywall links Privacy and Terms | done | `Corbie/Features/Paywall/PaywallView.swift:205`; `CorbieTests/PaywallCopyTests.swift:84` pins the two https URLs; `testPaywallTour` asserts both controls exist. |
| Sign in with Apple works | blocked on device test | `Corbie/Features/Onboarding/OnboardingIntroView.swift:129`. The simulator has no iCloud account (`AKAuthenticationError -7022` in the test log), so the real flow needs a device with an Apple ID. |
| The debug bypass is compiled out of Release | done | The button and the view model entry are both inside `#if DEBUG`: `Corbie/Features/Onboarding/OnboardingIntroView.swift:139` and `:147`, `Corbie/Features/Onboarding/OnboardingViewModel.swift:83`. `grep -n "debugSignIn" Corbie --include='*.swift' -r` returns only those lines plus the UI tests. |
| Account deletion exists | done | `Corbie/Features/Settings/SettingsView.swift:259` opens the confirmation, `SettingsViewModel.deleteAccount` (`:134`) deletes or leaves the space, revokes the Apple credential and wipes the device. `CorbieUITests/QASettingsUITests.swift` walks it and lands back on onboarding (screenshot `settings_after_delete`). |
| Privacy nutrition labels | not done | Nothing to change in the app: analytics carries enum names and counts only (`Packages/CorbieCore/Sources/CorbieCore/Services/AnalyticsEvent.swift`), identified by a device UUID (`AnonymousIdentity`). Answer the questionnaire as spec section 15 says: Data Not Linked to You, Usage Data and Diagnostics. |
| No placeholder text in the app | done | `CorbieTests/QAReleaseTests.swift` (`testNoPlaceholderCopyReachesTheEnglishStrings`) reads the compiled English strings table and fails on `lorem`, `todo`, `fixme`, `placeholder`, `tbd`, `xxx`. |
| No third-party SDKs | done | `Packages/CorbieCore/Package.swift` declares no runtime dependency; the only optional package (`swift-testing`) is added for tests when `CORBIE_EXTERNAL_TESTING=1`. |
| App icon | not done, blocker | `Corbie/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` declares one 1024x1024 universal slot and carries no image file. Submission is impossible until the two-raven mark from the brand book is exported into it. |
| Export compliance | done | `ITSAppUsesNonExemptEncryption` is `false` in `project.yml` (Corbie target info); asserted by `CorbieTests/QAReleaseTests.swift` (`testExportComplianceIsDeclared`). Answer the App Store Connect question as exempt. |
| Age rating | blocked on Apple account | 4+ per spec section 12. Nothing in the app produces user-generated public content; capsules and votes stay inside the pair. Fill the questionnaire in App Store Connect. |
| Permission strings match what the app asks for | done | Calendar full access, calendar write-only and photo library are declared and used; location, camera, contacts, Face ID and microphone are not declared and never requested. Asserted by `CorbieTests/QAReleaseTests.swift` (`testEveryPermissionTheAppAsksForHasAReason`, `testNoReasonIsDeclaredForAPermissionTheAppNeverAsksFor`). |
| First launch without network does not crash | done | The whole QA matrix runs against an unreachable server (see the next section) and against a simulator with no iCloud account. `CorbieUITests/QAOfflineUITests.swift` walks the invite and the link parser and both fail into a hint with a way out (screenshots `offline_invite_failed`, `offline_parse_failed`). |
| Read-only does not hide data | done | `CorbieUITests/QAReadOnlyUITests.swift` expires the trial through the developer menu, then the Tasks plus button raises the paywall while the calendar still opens its editor (screenshots `readonly_paywall`, `readonly_calendar_open`). |

## Release configuration

| Item | Status | Evidence |
| --- | --- | --- |
| `CORBIE_SERVER_URL` points at the real Supabase project | not done, blocker | The key is read in `Packages/CorbieCore/Sources/CorbieCore/Services/APIClientConfiguration.swift:4` and set nowhere: `grep -rn CORBIE_SERVER_URL --include='*.yml' --include='*.plist'` finds nothing. Every call falls back to `https://corbie.supabase.co/functions/v1` (`:36`). See `docs/KNOWN_ISSUES.md`. |
| CloudKit schema deployed from development to production | blocked on Apple account | Architecture section 18.4. Nothing in the repo can prove it; do it in the CloudKit dashboard before the first TestFlight build that ships to strangers. |
| App Store Server Notifications URL set for sandbox and production | blocked on Apple account | Architecture section 18.9. The server side lives in `server/supabase/functions`. |
| `DEVELOPMENT_TEAM` filled in | blocked on Apple account | `project.yml` ships an empty `DEVELOPMENT_TEAM`. |
| Version and build number | done | `MARKETING_VERSION` 1.0, `CURRENT_PROJECT_VERSION` 1 in `project.yml`; shown in settings through `settings.about.version`. |

## Store listing (spec section 12)

| Item | Status | Evidence |
| --- | --- | --- |
| Name, subtitle, categories, keywords | not done | Copy is written in spec section 12 and has to be typed into App Store Connect. |
| Six screenshots per size | not done | The QA run produces dark and light screenshots for three device sizes under the screenshot directory, but they are plain captures, not the angled marketing layout the spec asks for. |
| Preview video, 20 seconds | not done | Nothing recorded. |
| Store listing in five languages | not done, blocker for the localised listing | The app itself ships empty translations for de, es, fr and it; see `docs/KNOWN_ISSUES.md`. Do not publish localised listings before that is fixed. |
| Rating prompt after the third joint action, not before day five | not done | `SKStoreReviewController` / `requestReview` appears nowhere in the app. Spec section 12 asks for it. |
