# Test plan

What a machine checks, what a person has to check, and what came out of the run on 2026-09-06.

## 1. Automated

### Suites

| Suite | Where | Count | What it proves |
| --- | --- | --- | --- |
| `CorbieCoreTests` | `Packages/CorbieCore/Tests` | 473 | Repositories on an in-memory store, formatters, recurrence, FX, entitlement resolution, widget snapshots, App Intents, the Us badge rule, the Today feed. |
| `CorbieTests` | `CorbieTests` | 245 | View model logic, copy, routing, release facts (`QAReleaseTests`), relative dates (`QARelativeDateTests`). |
| `CorbieUITests` | `CorbieUITests` | 39 | The walks below, driven through the DEBUG-only "continue without Apple ID (debug build)" button. One of them skips itself: the paywall price needs StoreKit, which `xcodebuild` does not hand the app (`docs/KNOWN_ISSUES.md`). |
| Server | `server` | 111 | Deno tests for the Supabase functions. |

### UI walks

Every walk starts from an empty install: `XCUIApplication.corbie()` passes `-corbie-reset-store`,
which `DebugLaunch.resetStoreIfRequested` honours in `CorbieApp.init` under `#if DEBUG` and nowhere
else. It deletes both store files with their sidecars, the app group defaults and the keychain items
before Core Data opens, so no test depends on what the one before it left behind. Every suite goes
through it: the QA and Smoke walks through `launchSignedIn`, the others through
`UITestFlows.launchFresh`. Labels come from the string catalog through `QACatalog`, which the UI test
target compiles in, so a walk reads the same text the screen draws and never a hardcoded English
string.

| Test | What it does |
| --- | --- |
| `LaunchUITests` | Onboarding to five tabs, checks each tab is named after its catalog key, finds the Us pill on Today, one screenshot per tab. |
| `SmokeTabsUITests.testATaskIsCreatedTakenAndFinished` | Creates a free task, takes it, swipes it done, and checks it leaves the open list. |
| `SmokeTabsUITests.testAnEventIsCreatedAndListedUnderUpcoming` | Creates a date and finds it under Upcoming. |
| `SmokeTabsUITests.testAWishIsCreatedByHand` | Creates a wish by hand and finds it in the list. |
| `SmokeTabsUITests.testABigPlanTakesMoneyAndAPrepStep` | Creates a Big plan with a target, adds money, adds a prep step, reads the step's checkbox value back. |
| `SmokeTabsUITests.testAListTakesAnItemAndTicksIt` | Creates a list in the Lists segment, adds an item, ticks it, reads the value back. |
| `SmokeTabsUITests.testACapsuleIsCreatedFromTheUsHub` | Opens the Us hub from the pill, creates a capsule, finds it in the list. |
| `SmokeTabsUITests.testAVoteIsCreatedAndAnswered` | Creates a vote from a template, answers it, sees the answer recorded. |
| `SmokeTabsUITests.testAPersonWithABirthdayReachesTheCalendarAndToday` | Creates a person with a birthday 30 days out and finds it in the calendar and in Today's Coming up. |
| `TodayUITests` | Task due today and an event today, then the Today tab: the task in the Today block with a checkbox, the event in Events, the empty carousel offering "Add a plan", the new plan in the carousel, ticking the task, and the carousel tap landing on the plan inside the Plans tab. |
| `PlansUITests` | Plan money and a prep step from the plan screen, prep step drag reorder, a list item ticked. |
| `PeopleNavigationUITests` | A person opened from the hub shows their gift ideas once, and back returns to the list. |
| `FreeTimeUITests` | The calendar entry into free time raises the privacy sheet first, "Not now" leaves the screen usable, the range picker and filters are there. |
| `UsBadgeUITests` | An unanswered vote dots the Us pill and answering it clears the dot. |
| `QAUsBadgeUITests` | The second trigger a solo space can raise: a person whose birthday is seven days out with no gift picked dots the pill, and marking a gift idea picked clears it. |
| `QAReadOnlyUITests.testAnExpiredTrialLocksCreationAndKeepsTheCalendarAndToday` | Expires the trial through the developer menu: the Tasks plus raises the paywall with `paywall.reason.create`, the calendar still opens its editor, Today still draws the feed, and the Today checkbox raises the paywall with `paywall.reason.edit` without ticking the task. |
| `QAReadOnlyUITests.testTheWeeklyRecapStaysFreeAfterTheTrial` | With the trial expired, opens the weekly recap card and checks no paywall follows. Skips outside the card's window (Sunday 19:00 to Monday 09:00). |
| `QASettingsUITests.testTheThemeSegmentSwitchesAndGoesBack` | Switches the theme to Dark and back to System. |
| `QASettingsUITests.testTheExportProducesAFileTheShareSheetCanTake` | Exports the space and opens the system share sheet on the JSON file. |
| `QASettingsUITests.testTheBusyTimesToggleTurnsSharingOnAndOff` | Turns "Share my busy times" on and off again from the Privacy section. |
| `QASettingsUITests.testASoloSpaceOffersNoLeaveRowAndDeletesFromTheAccountSection` | Checks a solo space offers Delete account and no Leave space row. |
| `QASettingsUITests.testZDeletingTheAccountReturnsToOnboarding` | Deletes the account and lands back on onboarding. |
| `QADeepLinkUITests` | Opens `corbie://join/K7M2QX` through `XCUIDevice.shared.system.open`, checks the join sheet opens with the code filled in and closes cleanly. |
| `QAPermissionsUITests` | Calendar import, the photo picker and notifications, each with the system prompt denied. See section 3. |
| `QAOfflineUITests` | Invite and link parsing against an unreachable server. See section 2. |
| `QATapTargetUITests` | Measures the controls the app lays out itself against 44 points: the Tasks filter chip, Take on a task row, the Who segment, the due date toggle, the Today checkbox, the appearance segment. |
| `QAAppearanceUITests` | Screenshot tour of the five tabs, the Lists segment, the Us hub, settings top to bottom, and the paywall, in whatever appearance, text size and language the run asks for. Asserts the paywall carries Restore, Privacy, Terms and the auto-renew sentence. |
| `LocalizationUITests` | Onboarding, the five tabs, both Plans segments and the Us hub in each of the five languages, with every label written out in that language, and a screenshot per screen into `<screenshot dir>/<lang>`. |

### How to run

```
xcodegen generate
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max QA' \
  -derivedDataPath /tmp/corbie-dd-qa build-for-testing

xcrun simctl uninstall "iPhone 17 Pro Max QA" app.corbie

TEST_RUNNER_CORBIE_SCREENSHOT_DIR=/tmp/corbie-shots/promax_en_light \
TEST_RUNNER_CORBIE_UI_LANGUAGE=en \
TEST_RUNNER_CORBIE_UI_LARGE_TEXT=0 \
TEST_RUNNER_CORBIE_UI_APPEARANCE=light \
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max QA' \
  -derivedDataPath /tmp/corbie-dd-qa -only-testing:CorbieUITests test-without-building
```

`CORBIE_SCREENSHOT_PREFIX` still prefixes a file name if it is set; the runs below give each pass its
own directory instead, so the same screenshot name can be compared across devices and appearances.

The `TEST_RUNNER_` prefix is what carries a variable into the test runner process; without it the
runner sees nothing and no screenshot is written. `CORBIE_UI_LANGUAGE`, `CORBIE_UI_LARGE_TEXT` and
`CORBIE_UI_APPEARANCE` all become launch arguments on the app under test: `-AppleLanguages`,
`-AppleLocale`, `-UIPreferredContentSizeCategoryName`, and `-corbie.design.themePreference`, the app's
own Appearance setting.

Do not reach for `XCUIDevice.shared.appearance` or `xcrun simctl ui <device> appearance dark`: on Xcode
26.6 with the iOS 26.5 runtime neither changes what the app draws. `simctl` reports the new value back
and the springboard and the app both stay light, and the QA run before this one produced light
screenshots under dark file names because of it. The app's own Appearance segment is the switch that
works, and it is also the one a person can reach.

Every walk that types into a field reads English labels and skips itself in another language; the
screenshot tour, the launch walk and the deep link walk run in any language.

### Matrix

Devices: iPhone 17 Pro Max QA (large), iPhone 17e QA (small), iPhone 17 Badge (spare). There is no
iPhone SE runtime installed, so iPhone 17e stands in for the small screen.

| Pass | Devices | Language | Appearance | Text size | Suites |
| --- | --- | --- | --- | --- | --- |
| Full English light | all three | en | light | default | `CorbieUITests` |
| English dark | all three | en | dark | default | `QAAppearanceUITests` |
| English Dynamic Type XL | all three | en | light | `UICTContentSizeCategoryAccessibilityL` | `QAAppearanceUITests` |
| German light | all three | de | light | default | `QAAppearanceUITests`, `LaunchUITests` |
| German dark | all three | de | dark | default | `QAAppearanceUITests` |

Uninstall the app before each pass; the reset argument clears the store, the defaults and the
keychain but not the notification permission, which the system keeps per install.

The run on 2026-09-06 went through all five passes on all three devices. The full English light pass
reports `Executed 39 tests, with 1 test skipped and 0 failures` on each device, and so does the
closing run on iPhone 17 Pro Max after the last fix; the skip is the paywall price. The three dark
and Dynamic Type XL passes report `Executed 3 tests, with 1 test skipped`, the German light pass
`Executed 9 tests, with 1 test skipped`. Screenshots are one directory per pass (`promax_en_light`,
`promax_en_dark`, `promax_en_xl`, `promax_de_light`, `promax_de_dark`, `promax_final`, and the same
prefixes for `e17_` and `badge_`, plus `badge_permissions_denied`), with the localization walk
writing a subdirectory per language inside the pass it ran in.

## 2. Network paths and how they fail

The QA simulators have no route to the Supabase functions (see the server URL entry in
`docs/KNOWN_ISSUES.md`), so every run below is already an "unreachable server" run.

| Path | Code | Behaviour without a server | Observed |
| --- | --- | --- | --- |
| Invite code | `InviteViewModel`, `APIClient.createInvite` | The screen ends on `pairing.invite.failed.note` with a Try again button; Share code disappears; Later still leaves the screen. | Yes, `QAOfflineUITests.testAnUnreachableServerLeavesTheInviteScreenUsable`, screenshot `offline_invite_failed`. |
| Join a code | `JoinViewModel`, `APIClient.redeemInvite` | The failure is mapped to a `JoinFailure` line under the field; the redeemed share is kept so a retry resumes at the CloudKit step instead of burning a second code. | Read in code only; the join sheet opens and stays usable (`QADeepLinkUITests`). |
| Link parsing | `LinkParser`, `WishEditorViewModel.linkChanged` | The editor shows `wishes.editor.link.failed` and the title, price and photo stay editable. The wish is stored with `needsParse`, and `WishParseRetry` retries at most five per appearance once the network is back. | Yes, `QAOfflineUITests.testAnUnreachableParserStillLetsTheWishBeSavedByHand`, screenshot `offline_parse_failed`. |
| Currency rates | `FXService.rates` | A cached table per base currency is used first and answers again if the call throws (`FXService.swift:162`); the cache lives in the App Group with a 24 hour TTL. Wishes and plans never wait for the network to draw a price. | Read in code; the approximate figure is simply absent on a fresh install with no cache. |
| Entitlement | `EntitlementService.refresh`, `cachedState` | `cachedState` resolves from the keychain copy plus the status mirrored on the space without a call, so a paid pair keeps premium offline. `refresh` takes the local StoreKit entitlement first, then the server answer, then the mirror; a missing server answer alone cannot take premium away. | Read in code; every UI run forces premium through `DebugEntitlementOverride` and never calls the server. |
| StoreKit products | `StoreService.products` | No StoreKit configuration on the test action, so the paywall renders `paywall.state.unavailable` with a Try again button and the legal line still shows. | Yes, screenshot `paywall_top`. |
| Analytics | `Analytics` | Events go into a capped offline queue (500) saved to disk and flushed in batches of at most 20; a transport error keeps the batch, a permanent 4xx drops it. | Read in code, covered by `CorbieCoreTests` (`NetAnalyticsQueueTests`). |
| Session token | `SessionService` | Guarded by `isConfigured`, so with no server URL it never fires; a failure is reported as a toast and onboarding continues on the Apple identity token. | Read in code. |
| CloudKit sync | `NSPersistentCloudKitContainer` | The simulator has no iCloud account and logs `CKAccountStatusNoAccount` on every launch. The app works entirely on the local store. | Observed in every test log. |

Not exercised: a slow network (timeouts), a server that answers 5xx, and sync recovering after a long
offline stretch. The offline create-then-reconnect scenario from the module prompt needs two real
devices and is in section 6.

## 3. Permissions

Revoke first, then run the walk. `simctl privacy` has no notification service, so notifications are
denied by answering the prompt inside the test (`denySystemPromptIfShown`).

```
xcrun simctl privacy "iPhone 17 Badge" deny calendar app.corbie
xcrun simctl privacy "iPhone 17 Badge" deny photos app.corbie
xcrun simctl privacy "iPhone 17 Badge" deny location app.corbie
xcodebuild ... -only-testing:CorbieUITests/QAPermissionsUITests test-without-building
xcrun simctl privacy "iPhone 17 Badge" reset all app.corbie
```

The app has to be installed before `simctl privacy` can name it, so run a pass first, then deny, then
run the permission walk again. That is what the 2026-09-06 run did on iPhone 17 Badge: three tests,
no failures, screenshots in `badge_permissions_denied`. Denying at the system level takes the prompt
out of the picture entirely, which is a stronger check than answering it inside the test, and the
calendar screen still showed `calendar.import.denied.title` with Cancel working.

| Permission | Asked where | Denied behaviour | Observed |
| --- | --- | --- | --- |
| Notifications | On the first task with a due date, the first capsule, the first event, and the first change coming from the partner. Never at launch. | Settings, Notifications shows `settings.notifications.permission.denied` ("Turned off in iOS Settings") and an "Open iOS Settings" button. The nine toggles stay usable. | Yes, `QAPermissionsUITests.testDeniedNotificationsAreReportedInSettingsWithAWayBack`, screenshots `permission_notifications_prompt`, `permission_notifications_denied`. |
| Calendar | "Import from iPhone Calendar" (full access) and "Add to iPhone Calendar" on a date (write only). | The import screen shows `calendar.import.denied.title` with the mono line "turn it on in Settings, Privacy, Calendars" and Cancel still returns to Settings. | Yes, `QAPermissionsUITests.testCalendarImportSaysWhatToDoWhenAccessIsDenied`, screenshot `permission_calendar_denied`. |
| Photos | "Choose a photo" in the wish editor. | `PhotosPicker` is presented with `photoLibrary: .shared()`, which needs no permission of its own. The picker opens and Cancel returns to the editor. | Yes, `QAPermissionsUITests.testThePhotoPickerLeavesAWayBackWhenPhotosAreDenied`, screenshot `permission_photos_picker`. |
| Location | Never asked. | `grep -rn CLLocationManager Corbie CorbieWidgets CorbieShare Packages` finds nothing, and no location usage string is declared. Place search uses `MKLocalSearchCompleter`, which needs no permission, and the map draws pins without the blue dot. | Read in code, asserted by `CorbieTests/QAReleaseTests.swift` (`testNoReasonIsDeclaredForAPermissionTheAppNeverAsksFor`). |

## 4. What one person cannot check

The QA simulators run a solo space. These need a partner and go on the two-Apple-ID list:

- The Us badge from a wish added by the partner, and from a gift not yet picked for the partner's own
  birthday or the anniversary. A solo user can raise the dot from an unanswered vote, an unopened
  capsule and a person's birthday inside fourteen days with no gift picked; the automated suite does
  the vote (`UsBadgeUITests`) and the person (`QAUsBadgeUITests`).
- Every free time screen past the empty state: the slot list, the three filters, the two ranges,
  "Ask them", and the partner-has-not-shared state.
- Leave space: the row only renders when a partner exists.
- The vote reveal, the capsule recipient, the partner colour on rows, and every propagation timing.

## 5. Two Apple IDs, by hand

Needs two physical iPhones, two different Apple IDs, both signed in to iCloud with iCloud Drive on,
both on the same Wi-Fi, and a build installed from Xcode or TestFlight. The simulator cannot do this:
CloudKit sharing between two accounts is not supported there.

Timings below are what to expect on Wi-Fi. Anything slower than double them is a defect worth a bug.

1. **Create.** Phone A: launch, Sign in with Apple, name, colour, together-since, birthday, then Later
   on the invite screen. Expected: Today tab, trial running, "Trial ends soon" banner absent on day one.
2. **Invite.** Phone A: the Us pill, Shared settings, Partner, "Invite your partner". Expected: a six
   character code within 3 s and a countdown that starts at 15 minutes. Share it to phone B.
3. **Join.** Phone B: install, launch, Sign in with Apple with the second Apple ID, fill the profile,
   then "Have a code?" and type the code. Expected: "joining" for up to 15 s, then "You two are
   connected", then the tabs. Phone A shows the partner in Shared settings within 30 s.
4. **One subscription for two.** Phone A: subscribe with the 14 day introductory offer. Expected on
   phone B, which paid nothing and has no transaction on its Apple ID: premium within a minute, and
   Shared settings, Subscription showing the same end date phone A sees.
5. **Edits both ways.** Phone A: create a task assigned to nobody. Expected on phone B within 5 s: the
   task in Free with a Take button. Phone B: take it. Expected on phone A within 5 s: the task under
   In progress with phone B's colour and "took today". Repeat with a date, a wish, a plan money entry,
   a prep step, a list item tick and a person. Every one of them should land within 5 s with the app
   open.
6. **Notifications.** Phone B: mark the task done. Expected on phone A: a "Task taken" or "Back to
   free" style alert if the matching toggle is on, and no alert for the actions spec section 9 leaves
   silent.
7. **Widgets.** Add the Tasks, Shopping, OurDay and Days together widgets on both phones. Expected:
   the same contents on both within a minute, and ticking a task from phone A's widget removes it from
   phone B's within a minute.
8. **Capsule.** Phone A: write a capsule to the partner opening tomorrow. Expected on phone B: the
   card reads "a letter from ... is waiting" and cannot be opened. Move both phones to the next day
   and check the open-day notification arrives on both.
9. **Vote.** Phone A: create a vote with "Reveal when both answered" on. Answer on A. Expected on B:
   the options and "Their answer is hidden" until B answers, then the outcome on both.
10. **Free time.** Turn "Share my busy times" on for both. Expected: the free time screen lists windows
    where neither is busy, the Evenings, Weekends and 2+ hours filters narrow them, and turning the
    toggle off on phone B empties phone A's list within 60 s.
11. **Us badge.** Phone B: add a wish. Expected on phone A: a dot on the Us pill until the hub is
    opened. Give a person a birthday inside 14 days with no gift picked. Expected: the dot returns.
12. **Leave.** Phone B: Shared settings, Leave space, confirm. Expected: phone B lands on onboarding
    with no shared data; phone A still has everything and shows "Nobody yet. The space works solo."
    within 60 s.
13. **Delete.** Phone A: Shared settings, Delete account, confirm. Expected: phone A is wiped and back
    on onboarding, the space is gone from iCloud, and signing in again creates a fresh solo space.

Record for each step: the phone, the wall clock delay, and a screenshot if it took longer than the
expected window.

### 5a. Free time privacy audit in the CloudKit Dashboard

Do this with the two-Apple-ID run still fresh, before any submission.

1. Both phones: Shared settings, Privacy, turn "Share my busy times" on. Put at least one titled,
   located event with a guest in each phone's iPhone calendar inside the next 14 days.
2. Open the CloudKit Dashboard for the Corbie container, Development environment, the shared database
   for the pair, record type `CD_BusyInterval`.
3. Expected: every record carries only a start, an end, an all-day flag, a member id and a space id.
   No title, no location, no attendee, no notes field, in any record. Read the field list, not just
   the values, so an always-empty field still shows up.
4. Cross-check the writer: `BusyPublisher` and `CorbieEventBusyPublisher` in
   `Packages/CorbieCore/Sources/CorbieCore/Services` must not read a title or a location.
5. Phone A: turn the toggle off. Expected within 60 s: every `CD_BusyInterval` written by phone A's
   member id is gone from the dashboard, and phone B's free time screen falls back to
   "... hasn't shared their busy times yet".
6. Screenshot the dashboard record list before and after step 5 and keep it with the release notes.

### 5b. Today versus the OurDay widget

The Today feed and the widget snapshot both come from `TodayFeedProvider`, so they should agree.
Check all three data states on one phone, with the OurDay widget on the home screen:

1. **Empty.** A space with nothing in it. Expected: Today shows the empty state with Add a task, Add a
   date and Invite your partner; the widget shows its own empty line and no rows.
2. **Light.** One task due today, one event today, one Big plan. Expected: the same task title and the
   same event title in the same order in both, and the plan in Today's carousel.
3. **Full.** Five tasks due today, three events, two plans, a person with a birthday inside 14 days
   and an unanswered vote. Expected: the widget shows the same first rows as Today's blocks in the
   same order (plans, then tasks, then events), truncated to what fits, and never an item Today does
   not show.

After every change, wait for the widget to reload (the app posts `WidgetReloadRequest` on save) or
force it by backgrounding the app. Record any row that differs.

## 6. Offline and reconnect, by hand

1. Both phones in airplane mode. On each: create a task, a date, a wish, a plan money entry and a list
   item. Expected: everything saves and shows immediately, no spinner, no error toast; a wish with a
   link saves with no title filled in and no parse error blocking the save.
2. Turn Wi-Fi back on, one phone at a time, and wait a minute with the app open.
   Expected: every object appears on the other phone exactly once. No duplicates, no lost edits.
3. Edit the same task on both phones while offline (rename on A, take on B), then reconnect.
   Expected: both changes survive; last writer wins per field, and the task does not appear twice.
4. Repeat step 1 with the app killed between the edit and the reconnect.

## 7. Sandbox purchases, by hand

Needs a sandbox Apple ID (App Store Connect, Users and Access, Sandbox Testers), signed in under
Settings, Developer, Sandbox Apple Account on the device. Products come from App Store Connect, so
this cannot run before the two subscriptions exist there. Locally, `Products.storekit` reproduces the
same two products for the Run action only.

1. **Monthly.** Paywall, pick Monthly, Continue. Expected: the sandbox sheet shows the monthly price
   and "1 Month", the purchase confirms within 10 s, the paywall closes and Shared settings reads
   "Active until ...". The partner phone unlocks within 60 s without buying anything.
2. **Yearly.** Same with Yearly. Expected: the "Save 50%" badge on the card matches the real prices,
   and the small print names the yearly price, the yearly period, the Apple ID and the 24 hour window.
3. **Restore.** Delete the app, reinstall, sign in, open the paywall, "Restore purchases". Expected:
   "Subscription restored" and the paywall closes. On a fresh Apple ID with nothing to restore the
   line reads "Nothing to restore on this Apple ID" and the paywall stays open.
4. **Expiry to read only.** In the sandbox a monthly subscription renews every 5 minutes and expires
   after six renewals; use App Store Connect to cancel instead. Expected after the entitlement
   refresh (app foreground): the banner "Trial over. The calendar and Today still work.", the plus
   button on Tasks raises the paywall, the calendar keeps working, and nothing is deleted.
5. **Partner entitlement.** Buy on phone A only. Expected on phone B within 60 s of foregrounding:
   premium, with no purchase of its own, because the entitlement is fetched by space id.
6. **Upgrade.** With monthly active on phone A, buy Yearly. Expected: StoreKit offers the upgrade, the
   old subscription is replaced, and Shared settings shows the new expiry.
7. **Ask to buy.** With a sandbox account that has Ask to Buy on, buy anything. Expected: the paywall
   shows "This purchase is waiting for approval. Corbie unlocks as soon as it goes through." and the
   app stays usable.

Every purchase must carry `appAccountToken = Space.id`
(`Packages/CorbieCore/Sources/CorbieCore/Services/StoreService.swift:58`). Check in App Store Connect
that the transaction carries the token, otherwise the server cannot map it to the space.

## 8. The paywall with prices, by hand

`xcodebuild test` runs without a StoreKit configuration (`docs/KNOWN_ISSUES.md`), so the price and the
period on the paywall are a manual check until a test plan carries the configuration.

1. Open `Corbie.xcodeproj` in Xcode and run the Corbie scheme on a simulator. The Run action has
   `Products.storekit` attached, so StoreKit answers.
2. Us pill, Shared settings, Subscription, See plans.
3. Expected on screen at once: the monthly card with a price, the yearly card with a price, a "Save
   n%" badge and a per-month equivalent under the yearly price, the auto-renew sentence naming that
   price and period, Restore purchases, Privacy Policy and Terms of Use.
4. Screenshot it for the App Review notes.

## 9. Device-only checks

- All thirteen widgets on a real home screen and lock screen, in light and dark, small, medium and
  large, and after a locale change.
- The share extension from Safari and from Instagram.
- Sign in with Apple, including a second launch without network, and credential revocation
  (Settings, Apple ID, Password and Security, Apps using your Apple ID, Corbie, Stop using).
- Dynamic Type at the largest accessibility size on a 4.7 inch device.
- VoiceOver on the Tasks list, the paywall and the vote screen.
