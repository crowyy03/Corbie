# Test plan

What a machine checks, what a person has to check, and what came out of the run on 2026-09-06.

## 1. Automated

### Suites

| Suite | Where | Count | What it proves |
| --- | --- | --- | --- |
| `CorbieCoreTests` | `Packages/CorbieCore/Tests` | 331 | Repositories on an in-memory store, formatters, recurrence, FX, entitlement resolution, widget snapshots, App Intents. |
| `CorbieTests` | `CorbieTests` | 185 | View model logic, copy, routing, release facts (`QAReleaseTests`), relative dates (`QARelativeDateTests`). |
| `CorbieUITests` | `CorbieUITests` | 16 | The walks below, driven through the DEBUG-only "continue without Apple ID (debug build)" button. |
| Server | `server` | 111 | Deno tests for the Supabase functions. |

### UI walks

| Test | What it does |
| --- | --- |
| `LaunchUITests.testSignInReachesFiveTabs` | Onboarding to five tabs, one screenshot per tab. |
| `SmokeTabsUITests.testTaskCreateTakeAndDone` | Creates a free task, takes it, swipes it done, and checks it leaves the open list. |
| `SmokeTabsUITests.testEventCreateShowsInUpcoming` | Creates a date and finds it under Upcoming. |
| `SmokeTabsUITests.testWishManualCreate` | Creates a wish by hand and finds it in the list. |
| `SmokeTabsUITests.testPlanCreateAndExpenseInPlanCurrency` | Creates a plan with a target, adds an expense in the plan currency, finds it on the plan. |
| `SmokeTabsUITests.testListCreateAddItemAndTick` | Creates a list, adds an item, ticks it, and reads the checkbox value back. |
| `SmokeTabsUITests.testCapsuleCreate` | Creates a capsule from the Us tab and finds it in the list. |
| `SmokeTabsUITests.testVoteCreateAndAnswer` | Creates a vote from a template, answers it, and sees the answer recorded. |
| `SmokeTabsUITests.testPersonWithBirthdayReachesTheCalendar` | Creates a person with today's birthday and finds the birthday in the calendar. |
| `QAReadOnlyUITests` | Expires the trial through the developer menu, checks the Tasks plus button raises the paywall and the calendar still opens its editor, then resets the trial. |
| `QASettingsUITests.testThemeSwitchAndExport` | Switches the theme to Dark and back, exports the space and opens the system share sheet. |
| `QASettingsUITests.testZDeleteAccountReturnsToOnboarding` | Deletes the account and lands back on onboarding. |
| `QADeepLinkUITests` | Opens `corbie://join/K7M2QX` through `XCUIDevice.shared.system.open`, checks the join sheet opens with the code filled in. |
| `QAPermissionsUITests` | Calendar denied, photos denied, notifications denied. See section 3. |
| `QAOfflineUITests` | Invite and link parsing against an unreachable server. See section 2. |
| `QAAppearanceUITests` | Screenshot tour of the five tabs, settings and the paywall, in whatever appearance, text size and language the run asks for. |

### How to run

```
xcodegen generate
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Tests' \
  -derivedDataPath /tmp/corbie-dd-qa build-for-testing

TEST_RUNNER_CORBIE_SCREENSHOT_DIR=/tmp/corbie-shots \
TEST_RUNNER_CORBIE_SCREENSHOT_PREFIX=t17_en_light \
TEST_RUNNER_CORBIE_UI_LANGUAGE=en \
TEST_RUNNER_CORBIE_UI_LARGE_TEXT=0 \
TEST_RUNNER_CORBIE_UI_APPEARANCE=light \
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Tests' \
  -derivedDataPath /tmp/corbie-dd-qa -only-testing:CorbieUITests test-without-building
```

`CORBIE_UI_LANGUAGE` and `CORBIE_UI_LARGE_TEXT` become launch arguments on the app under test
(`-AppleLanguages`, `-AppleLocale`, `-UIPreferredContentSizeCategoryName`).
`CORBIE_UI_APPEARANCE` drives `XCUIDevice.shared.appearance`.
Every walk except the screenshot tour reads English labels and skips itself in another language.

### Matrix

Run on iPhone 17 Tests, iPhone 17 Pro Max QA and iPhone 17e QA (the small-screen stand-in; there is
no iPhone SE runtime installed). Each device runs, in order: the full English light pass, then the
screenshot tour in English dark, English at `UICTContentSizeCategoryAccessibilityL`, German light and
German dark, then the permission walk with calendar, photos and location revoked, then the settings
walk (it deletes the account, so it goes last).

## 2. Network paths and how they fail

The QA simulators have no route to the Supabase functions (see the server URL entry in
`docs/KNOWN_ISSUES.md`), so every run below is already an "unreachable server" run.

| Path | Code | Behaviour without a server | Observed |
| --- | --- | --- | --- |
| Invite code | `InviteViewModel`, `APIClient.createInvite` | The screen ends on `pairing.invite.failed.note` with a Try again button; Share code disappears; Later still leaves the screen. | Yes, `QAOfflineUITests.testAnUnreachableServerLeavesTheInviteScreenUsable`, screenshot `offline_invite_failed`. |
| Join a code | `JoinViewModel`, `APIClient.redeemInvite` | The failure is mapped to a `JoinFailure` line under the field; the redeemed share is kept so a retry resumes at the CloudKit step instead of burning a second code. | Read in code only; the join sheet opens and stays usable (`QADeepLinkUITests`). |
| Link parsing | `LinkParser`, `WishEditorViewModel.linkChanged` | The editor shows `wishes.editor.link.failed` and the title, price and photo stay editable. The wish is stored with `needsParse`, and `WishParseRetry` retries at most five per appearance once the network is back. | Yes, `QAOfflineUITests.testAnUnreachableParserStillLetsTheWishBeSavedByHand`, screenshot `offline_parse_failed`. |
| Currency rates | `FXService.rates` | A cached table per base currency is used first and answers again if the call throws (`FXService.swift:162`); the cache lives in the App Group with a 24 hour TTL. Wishes and plans never wait for the network to draw a price. | Read in code; the approximate figure is simply absent on a fresh install with no cache. |
| Entitlement | `EntitlementService.refresh`, `cachedState` | `cachedState` resolves from the keychain copy plus `Space.trialEndsAt` without a call, so the trial keeps working offline. `refresh` mixes the server answer, the local StoreKit transaction and the trial; a missing server answer alone cannot take premium away. | Read in code; every UI run is on the trial with no server. |
| Analytics | `Analytics` | Events go into a capped offline queue (500) saved to disk and flushed in batches of at most 20; a transport error keeps the batch, a permanent 4xx drops it. | Read in code, covered by `CorbieCoreTests` (`NetAnalyticsQueueTests`). |
| Session token | `SessionService` | Guarded by `isConfigured`, so with no server URL it never fires; a failure is reported as a toast and onboarding continues on the Apple identity token. | Read in code. |
| CloudKit sync | `NSPersistentCloudKitContainer` | The simulator has no iCloud account and logs `CKAccountStatusNoAccount` on every launch. The app works entirely on the local store. | Observed in every test log. |

Not exercised: a slow network (timeouts), a server that answers 5xx, and sync recovering after a long
offline stretch. The offline create-then-reconnect scenario from the module prompt needs two real
devices and is in section 5.

## 3. Permissions

| Permission | Asked where | Denied behaviour | Observed |
| --- | --- | --- | --- |
| Notifications | On the first task with a due date, the first capsule, the first event, and the first change coming from the partner. Never at launch. | Settings, Notifications shows `settings.notifications.permission.denied` ("Turned off in iOS Settings") and an "Open iOS Settings" button. The nine toggles stay usable. | Yes, `QAPermissionsUITests.testDeniedNotificationsStillOfferAWayBack`, screenshots `permission_notifications_prompt`, `permission_notifications_denied`. |
| Calendar | "Import from iPhone Calendar" (full access) and "Add to iPhone Calendar" on a date (write only). | The import screen shows `calendar.import.denied.title` with the mono line "turn it on in Settings, Privacy, Calendars" and Cancel still works. | Yes, `QAPermissionsUITests.testCalendarImportSaysWhatToDoWhenAccessIsDenied`, screenshot `permission_calendar_denied`. |
| Photos | "Choose a photo" in the wish editor. | `PhotosPicker` is presented with `photoLibrary: .shared()`. The picker opens and can be cancelled back into the editor. | Yes, `QAPermissionsUITests.testThePhotoPickerIsReachableWithPhotosDenied`, screenshot `permission_photos_denied`. |
| Location | Never asked. | `grep -rn CLLocationManager Corbie CorbieWidgets CorbieShare Packages` finds nothing, and no location usage string is declared. Place search uses `MKLocalSearchCompleter`, which needs no permission, and the map draws pins without the blue dot. | Read in code, asserted by `CorbieTests/QAReleaseTests.swift` (`testNoReasonIsDeclaredForAPermissionTheAppNeverAsksFor`). |

## 4. Two Apple IDs, by hand

Needs two physical iPhones, two different Apple IDs, both signed in to iCloud with iCloud Drive on,
both on the same Wi-Fi, and a build installed from Xcode or TestFlight. The simulator cannot do this:
CloudKit sharing between two accounts is not supported there.

Timings below are what to expect on Wi-Fi. Anything slower than double them is a defect worth a bug.

1. **Create.** Phone A: launch, Sign in with Apple, name, colour, together-since, birthday, then Later
   on the invite screen. Expected: Tasks tab, trial running, "Trial ends soon" banner absent on day one.
2. **Invite.** Phone A: Us, Couple settings, Partner, "Invite your partner". Expected: a six character
   code within 3 s and a countdown that starts at 15 minutes. Share it to phone B.
3. **Join.** Phone B: install, launch, Sign in with Apple with the second Apple ID, fill the profile,
   then "Have a code?" and type the code. Expected: "joining" for up to 15 s, then "You two are
   connected", then the tabs. Phone A shows the partner in Couple settings within 30 s.
4. **Trial extension.** Phone A: Couple settings, Subscription. Expected: the trial has been pushed to
   seven days from the join, once and only once (`TrialExtensionGuard`).
5. **Edits both ways.** Phone A: create a task assigned to nobody. Expected on phone B within 5 s: the
   task in Free with a Take button. Phone B: take it. Expected on phone A within 5 s: the task under
   In progress with phone B's colour and "took today". Repeat with a date, a wish, a plan expense, a
   list item tick and a person. Every one of them should land within 5 s with the app open.
6. **Notifications.** Phone B: mark the task done. Expected on phone A: a "Task taken" or "Back to
   free" style alert if the matching toggle is on, and no alert for the actions spec section 9 leaves
   silent.
7. **Widgets.** Add the Tasks, Shopping and Days together widgets on both phones. Expected: the same
   contents on both within a minute, and ticking a task from phone A's widget removes it from phone
   B's within a minute.
8. **Capsule.** Phone A: write a capsule to the partner opening tomorrow. Expected on phone B: the
   card reads "a letter from ... is waiting" and cannot be opened. Move both phones to the next day
   and check the open-day notification arrives on both.
9. **Vote.** Phone A: create a vote with "Reveal when both answered" on. Answer on A. Expected on B:
   the options and "Their answer is hidden" until B answers, then the outcome on both.
10. **Leave.** Phone B: Couple settings, Leave space, confirm. Expected: phone B lands on onboarding
    with no shared data; phone A still has everything and shows "Nobody yet. The space works solo."
    within 60 s.
11. **Delete.** Phone A: Couple settings, Delete account, confirm. Expected: phone A is wiped and back
    on onboarding, the space is gone from iCloud, and signing in again creates a fresh solo space.

Record for each step: the phone, the wall clock delay, and a screenshot if it took longer than the
expected window.

## 5. Offline and reconnect, by hand

1. Both phones in airplane mode. On each: create a task, a date, a wish, a plan expense and a list
   item. Expected: everything saves and shows immediately, no spinner, no error toast; a wish with a
   link saves with no title filled in and no parse error blocking the save.
2. Turn Wi-Fi back on, one phone at a time, and wait a minute with the app open.
   Expected: every object appears on the other phone exactly once. No duplicates, no lost edits.
3. Edit the same task on both phones while offline (rename on A, take on B), then reconnect.
   Expected: both changes survive; last writer wins per field, and the task does not appear twice.
4. Repeat step 1 with the app killed between the edit and the reconnect.

## 6. Sandbox purchases, by hand

Needs a sandbox Apple ID (App Store Connect, Users and Access, Sandbox Testers), signed in under
Settings, Developer, Sandbox Apple Account on the device. Products come from App Store Connect, so
this cannot run before the two subscriptions exist there. Locally, `Products.storekit` reproduces the
same two products for the Run action only.

1. **Monthly.** Paywall, pick Monthly, Continue. Expected: the sandbox sheet shows the monthly price
   and "1 Month", the purchase confirms within 10 s, the paywall closes and Couple settings reads
   "Active until ...". The partner phone unlocks within 60 s without buying anything.
2. **Yearly.** Same with Yearly. Expected: the "Save 50%" badge on the card matches the real prices,
   and the small print names the yearly price, the yearly period, the Apple ID and the 24 hour window.
3. **Restore.** Delete the app, reinstall, sign in, open the paywall, "Restore purchases". Expected:
   "Subscription restored" and the paywall closes. On a fresh Apple ID with nothing to restore the
   line reads "Nothing to restore on this Apple ID" and the paywall stays open.
4. **Expiry to read only.** In the sandbox a monthly subscription renews every 5 minutes and expires
   after six renewals; use App Store Connect to cancel instead. Expected after the entitlement
   refresh (app foreground): the banner "Trial over. The calendar still works.", the plus button on
   Tasks raises the paywall, the calendar keeps working, and nothing is deleted.
5. **Partner entitlement.** Buy on phone A only. Expected on phone B within 60 s of foregrounding:
   premium, with no purchase of its own, because the entitlement is fetched by space id.
6. **Upgrade.** With monthly active on phone A, buy Yearly. Expected: StoreKit offers the upgrade, the
   old subscription is replaced, and Couple settings shows the new expiry.
7. **Ask to buy.** With a sandbox account that has Ask to Buy on, buy anything. Expected: the paywall
   shows "This purchase is waiting for approval. Corbie unlocks as soon as it goes through." and the
   app stays usable.

Every purchase must carry `appAccountToken = Space.id`
(`Packages/CorbieCore/Sources/CorbieCore/Services/StoreService.swift:58`). Check in App Store Connect
that the transaction carries the token, otherwise the server cannot map it to the space.

## 7. Device-only checks

- All thirteen widgets on a real home screen and lock screen, in light and dark, small, medium and
  large, and after a locale change.
- The share extension from Safari and from Instagram.
- Sign in with Apple, including a second launch without network, and credential revocation
  (Settings, Apple ID, Password and Security, Apps using your Apple ID, Corbie, Stop using).
- Dynamic Type at the largest accessibility size on a 4.7 inch device.
- VoiceOver on the Tasks list, the paywall and the vote screen.
