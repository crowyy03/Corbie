# Two-Apple-ID test session

A session plan for two physical iPhones on two different Apple IDs, in the order to run it. It
expands `docs/TEST_PLAN.md` section 5 and 5a for module 21.

Written on 2026-09-17 against `main` at `cac7abf` plus the uncommitted module 21 work in the same
checkout (team id, `yourcorbie.app` links, the server monetization flag). Every "See" line comes from
the code and from the English values in `Corbie/Resources/Localizable.xcstrings`. Nothing here was run
on a device. Timings are the targets from `docs/TEST_PLAN.md` section 5 and the limits written in the
code, not measurements.

Updated on 2026-09-17 after the persistence fix round A (commit `63e4af1`): open questions 1, 3,
5 and 6 are fixed in the code, and steps 8, 8b, 13, 13b, 14 and 16 say what that build should show.
The fixes were checked by unit tests and by reading the code, not on a device.

Updated again on 2026-09-17 after fix round B (commit `2e15dfa`): open questions 2, 7 and 9 are fixed,
steps 4, 6e, 8, 9, 12a and 12c say what that build should show, and the new step 9e checks a phone whose
Corbie is not in memory. A silent push that launches the app in the background cannot be produced on
a simulator, so everything about the background path in steps 8, 9 and 9e is unchecked until this
session runs.

Names used below:

- **Phone A** is the owner. It creates the space.
- **Phone B** is the partner. It joins the space.
- **Us pill** is the pair of coloured dots at the top right of every tab (VoiceOver: "Open the Us hub").
- **Shared settings** is the tile at the bottom of the Us hub. The screen it opens is titled "Settings".
- **Dashboard** is the CloudKit Console at `https://icloud.developer.apple.com`.

Each step has four parts: **Do**, **See**, **Time**, **If it fails**. Section 6 lists the places where
the code itself makes a step doubtful. Section 7 is the sheet to fill in.

---

## 1. Pre-flight

Do all of this before the session starts. Budget 45 minutes.

| # | Check | Why |
| --- | --- | --- |
| 1 | Two iPhones on iOS 17 or later, Developer Mode on (Settings, Privacy & Security, Developer Mode). | Xcode installs Debug builds only with Developer Mode on. Interactive widgets need iOS 17 (`project.yml`, deployment target 17.0). |
| 2 | Each phone signed in to iCloud with its own Apple ID. iCloud Drive on. After the first launch, Settings, your name, iCloud, apps using iCloud: Corbie on. | Both stores sync through container `iCloud.app.corbie` (`CoreDataStack.storeDescriptions`). Sign in with Apple uses the Apple ID of the phone. |
| 3 | Same language (English) and region on both. Settings, General, Date & Time: "Set Automatically" on. | The question of the day is picked per language (`QuestionCopy`). Step 10 compares the text. |
| 4 | Low Power Mode off. Low Data Mode off for Wi-Fi and cellular. Background App Refresh on, and on for Corbie. Focus off. | Partner changes arrive as silent pushes (`UIBackgroundModes: remote-notification` in `project.yml`). iOS holds them back in these modes. |
| 5 | Signing works: `docs/APPLE_MANUAL_STEPS.md` section 1 is done (Apple Development certificate, no red errors under Signing & Capabilities for all three targets). | Team `735XXP9B5R` is set in `project.yml`. This Mac had no signing identity when that checklist was written. |
| 6 | Build: `xcodegen generate`, open `Corbie.xcodeproj`, scheme **Corbie**, Run (Debug) on phone A, then on phone B, from the same checkout state. Write down `git rev-parse --short HEAD` and whether the tree had local changes. `git log --oneline` must contain `63e4af1` and `2e15dfa`. | Both phones must run the same code. Steps 8, 8b, 13, 13b, 14 and 16 describe the build with the persistence fixes, steps 4, 6e, 8, 9, 9e, 12a and 12c the build with fix round B. |
| 7 | The build carries the module 21 changes. Check in the checkout: `Configs/Corbie.entitlements` lists `applinks:yourcorbie.app`, and `CorbieIdentifiers.universalLinkHost` is `"yourcorbie.app"`. | `main` at `cac7abf` still says `corbie.app` in all three places (entitlement, `Router.isCorbieHost`, `InviteLink`), so steps 3 and 15 fail on a build from `main`. |
| 8 | Delete Corbie from both phones before installing. | Steps 3 and 4 need a fresh install on B. |
| 9 | Never tap "continue without Apple ID (debug build)" on the intro screen. Use the Sign in with Apple button. | That button stores the fixed id `debug.simulator.user` (`OnboardingViewModel.swift:93`). With it on both phones, B's join finds A's member by that id and both phones become the same person (`CoreDataMemberRepository.upsertCurrentMember`). |
| 10 | CloudKit environment: a Debug build signed by Xcode uses **Development** (`aps-environment` is `development` in `Configs/Corbie.entitlements`, and a development-signed app carries no production container environment). In the Dashboard, always pick **Development**. | Data from this session never appears in Production. See section 2. |
| 11 | Old Development data: if either Apple ID ever ran a Corbie Debug build, its data comes back on install. After signing in on A (step 1), the profile screen must be empty apart from the Apple name, and Today must read "Nothing on today". If not, clear that Apple ID first (section 1.1). | `OnboardingViewModel.loadProfile` reuses any space already in the store. On B, old data makes the join fail with "This space already has things in it, and two spaces cannot be merged yet." |
| 12 | Server: live at `powtuiqqagdoiuqjeebr`, nothing to do for this session. Invite codes and redeem have worked since the deploy of 2026-09-12 (`server/DEPLOY.md`). `POST /session` has never run with a real Apple token before: step 1 is its first real call. | |
| 13 | Monetization is off, so both phones have full access. Server check: `curl -s https://powtuiqqagdoiuqjeebr.supabase.co/functions/v1/config` should print `{"monetizationEnabled":false}`. On 2026-09-17 it answered `404 Requested function was not found`, because migration `0006_app_config.sql` and the `config` function are not deployed yet (`server/DEPLOY.md`, first paragraph). That does not block the session: a value the app never fetched counts as off (`MonetizationFlagStore.isEnabled`). In-app check on each phone: Us pill, Shared settings, About, "Developer" (Debug builds only), section "Monetization". The footer must read `effective: off` and `forced: none`. If `forced` is not `none`, tap "Follow the server flag". Touch nothing else on the Developer screen. | With the flag off, Settings has no "Subscription" section, the Shared settings tile reads "names, dates and notifications", no trial offer screen appears, and no widget shows "Unlock in Corbie". Any of those appearing means the flag is not off on that phone. |
| 14 | Notification permission: A grants it in step 1, B in step 5. Afterwards, Shared settings, Notifications, "Permission" must read "Allowed" on both. On both phones, in the same screen, these switches must be on: "Task assigned to you", "Task taken or handed back", "Partner added a wish", "Plan money: expense, goal, over budget", "Question of the day", "Chore split". | Corbie never asks at launch (`docs/TEST_PLAN.md` section 3). A refused prompt can only be undone in iOS Settings. |
| 15 | Calendar events for the privacy audit: on each phone, in the iPhone Calendar app, one event in the next 14 days with a title, a location and at least one invitee. Create them now. | Step 12 checks that none of this reaches CloudKit. |
| 16 | Network: both phones on the same Wi-Fi to start. Step 7 moves one phone to cellular: check Settings, Cellular, Corbie is on. | Both phones on one Wi-Fi share one public IP. The server allows 30 invites, 30 sessions and 60 redeems per hour per IP (`server/API.md`). The session uses a handful. |
| 17 | Never force-quit Corbie unless a step says so. Background (Home Screen, or another app) is fine and is what steps 8 and 9 test. | Alerts about partner changes are made by the receiving app itself when the change arrives (`RemoteChangeNotifier`). iOS launches or resumes Corbie in the background for a silent push, but not after a force-quit, until Corbie is opened again. |
| 18 | Dashboard: sign in at `https://icloud.developer.apple.com` with the Apple ID of team `735XXP9B5R`. Have both test Apple ID passwords ready for "Act as iCloud Account". | Private and shared data is visible only while acting as the account that owns it. |
| 19 | Time budget: about 4 hours for sections 4 and 5, plus one check at 20:00 local time (step 9c). If the session ends before 20:00, run steps 13 and 14 after that check. | Leaving and deleting cancel every pending Corbie notification (`NotificationScheduler.cancelEverything`). |
| 20 | Logs: the Mac with Console.app, both phones connected by cable at least for steps 8, 9 and 9e. In Console, pick the phone, press Start, and search for `remote-push`. | Every silent push Corbie handles writes one line, for example `push for the shared store: import finished, newData after 4.2 s` (the seconds print with more digits) (subsystem `app.corbie`, category `remote-push`, `RemotePushSync.finish`). It is the only way to tell "the push never came" from "the push came and the rule said nothing". |

### 1.1 Clearing old Development data (only if check 11 fails)

1. Delete Corbie from the affected phone.
2. Dashboard, CloudKit Database, container `iCloud.app.corbie`, environment Development.
3. "Act as iCloud Account" with that Apple ID. Database: Private. Zones: delete
   `com.apple.coredata.cloudkit.zone` and every `com.apple.coredata.cloudkit.share.` zone.
4. Reinstall and repeat check 11.

The heavier option is "Reset Environment" for Development. It wipes all Development data and the
Development schema for every account. After it, run the app once with `CORBIE_INIT_SCHEMA=1`
(`docs/APPLE_MANUAL_STEPS.md` section 2, steps 1 and 2) so every record type exists again before any
production deploy.

I did not open the Dashboard while writing this. The menu names are from memory and may differ
slightly.

---

## 2. What waits for the production schema deploy

- **Nothing in this session.** A Debug build uses the Development environment, where the schema grows
  as records are written. The session can run before "Deploy Schema Changes".
- **A TestFlight or App Store build** uses Production. Until the schema is deployed there
  (`docs/APPLE_MANUAL_STEPS.md` section 2), expect step 2 to fail already: creating the share saves
  `CD_` records whose types do not exist in Production. Everything after it fails too: join,
  propagation, the other phone's widgets, partner alerts, question sync, chore split, free time, and
  leave or delete in iCloud. Only things local to one phone still work. Not checked on a TestFlight
  build.
- The space model has 25 entities (`CorbieModel.swift`), so Development must show 25 `CD_` record
  types before the deploy.

---

## 3. Known issues you will see (do not report them as new)

From `docs/KNOWN_ISSUES.md`:

- The Us hub counters show "-" when there is nothing to count, for example when together-since was
  skipped.
- The Us pill and the toolbar Save button look short: bar items are 36 points tall.
- Notifications are asked for once. After a refusal, only Settings, Notifications, "Open iOS
  Settings" brings them back, and a task due date or a capsule schedules nothing without a word.
- VoiceOver reads a list item's title twice ("Milk, button" two times).
- Free time and half of the Us badge need a partner. That is what this session covers.

From other docs and the Debug build:

- While `APPLE_TEAM_ID`, `APPLE_KEY_ID` and `APPLE_PRIVATE_KEY` are not set, `POST /session` cannot
  turn the sign-in code into a refresh token, so the phone stores none and deleting the account sends
  no revoke at all. Set the three secrets before the phones sign in for this session; a phone that
  signed in earlier has to sign out and in again to get a token. See also open question 4.
- If `POST /session` refuses the Apple token, a toast shows after Sign in with Apple and onboarding
  continues (`docs/TEST_PLAN.md` section 2).
- Debug-only items: "continue without Apple ID (debug build)" on the intro screen, and "Developer" at
  the bottom of Settings.
- A change made from a widget or from the share sheet reaches the partner only after the person who
  made it opens Corbie (`docs/KNOWN_ISSUES.md`). Steps 8 and 8b expect exactly that.
- A partner who deletes the app without leaving stays the partner on the owner's phone
  (`docs/KNOWN_ISSUES.md`). Do not delete the app on B during the session.

---

## 4. Session

### Step 1. Create the space (phone A)

**Do.** Launch Corbie. Tap "Sign in with Apple" and confirm. On "Your side of the space" fill Name,
Color, Birthday ("Add month and day") and Together since ("Set a date"), then "Continue". On "Invite
your partner" tap "Later". Then Tasks tab, the plus button, "New task": What to do "Pre-flight task",
Due: "Set a date" on, "Save". When iOS asks about notifications, tap Allow.

**See.**
- After "Later": the Today tab. No trial offer screen. No toast after Sign in with Apple.
- The task in Tasks.
- Us pill, Shared settings, section Partner: "Nobody yet. The space works solo.", then "Invite your
  partner" and "Have a code?". No "Subscription" section.

**Time.** Under a minute from Face ID to Today.

**If it fails.**
- Toast "Sign in again to continue." or "No answer from the network." right after Sign in with Apple:
  `POST /session` refused the identity token (`SessionService.exchange`; the server checks that the
  token's audience is `APPLE_CLIENT_ID`, `app.corbie`). Onboarding continues, but invites then work
  only while the Apple token is fresh, about 10 minutes (the token provider in `AppEnvironment.init`
  falls back to it). Look at the `session` function logs in Supabase.
- The Apple sheet shows an error: Sign in with Apple is missing on App ID `app.corbie` in the
  developer portal, or from the signed app.
- Profile already filled, or old items on Today: old Development data (section 1.1).
- Toast "That did not save." on launch: App Group `group.app.corbie` is missing from the signed app
  (`CoreDataStack.appGroupFailure`).

### Step 2. Invite by code (phone A)

**Do.** Us pill, "Shared settings", Partner, "Invite your partner". Wait for the code. Tap "Share
code" and send it to B in Messages. Leave this sheet open until step 4 ends. Do not close and reopen
it: every time the invite screen appears it makes a new code, and the server expires the previous
unused one (`InviteView` `.task`, `server/supabase/functions/invite/index.ts` line 48).

**See.** Title "Invite your partner", note "one code, fifteen minutes", then "making a code" with a
spinner, then six characters (letters and digits, no 0, O, 1, I or L) and "expires in 14:59" counting
down. The shared message reads "Join me on Corbie: https://yourcorbie.app/join/" followed by the code.

**Time.** Code within 5 s. The first time, a CloudKit share is created too (`CloudKitSharing.share`).
`docs/TEST_PLAN.md` says 3 s. Over 15 s is a defect.

**If it fails** (the card reads "no code yet - check the connection and try again" with "Try again"):
- Toast "iCloud did not answer.": creating the share failed. iCloud not signed in, iCloud Drive off,
  the container missing from the provisioning profile, or a TestFlight build without the production
  schema (section 2).
- Toast "Sign in again to continue.": `POST /invite` answered 401. The session token is missing (see
  step 1) and the Apple token is older than about 10 minutes. There is no sign-out in the app: delete
  and reinstall, or fix `POST /session`.
- Toast "No answer from the network.": the server is down, or 30 invites were already made from this
  IP within the hour.
- The link says `corbie.app`: the build came from `main`, not from the module 21 checkout (pre-flight
  7).

### Step 3. Accept, part 1: the universal link (phone B)

**Do.** Install Corbie on B. Do not open it. In Messages, tap A's link. Sign in with Apple with B's
Apple ID, fill the profile, tap "Continue". On the screen that follows, do not tap "Join". Tap
"Later".

**See.**
- Corbie opens, not Safari, on the intro pages.
- After "Continue": the "Have a code?" screen with A's six characters already in the "Invite code"
  field.
- After "Later": "Invite your partner" with B's own code. Ignore it and do not share it.

Why it stops here: the code is used up only when "Join" is tapped (`JoinViewModel.redeemedShare`), so
"Later" keeps it valid for step 4, which tests typing the code. Step 15 does the full join from a
link.

**Time.** The app opens within 2 s of the tap.

**If it fails.**
- Safari opens the yourcorbie.app home page: iOS has not tied the domain to the app. Check pre-flight
  7, delete and reinstall, tap again. The site side is fine: on 2026-09-17
  `https://yourcorbie.app/.well-known/apple-app-site-association` answered 200, `application/json`,
  app `735XXP9B5R.app.corbie`, path `/join/*`. A link typed or pasted into Safari's address bar never
  opens the app, so tap it inside Messages or Notes. If Safari was chosen once, long-press the link
  and pick "Open in Corbie".
- The app opens but the field is empty: the host did not match (`Router.isCorbieHost`, build from
  `main`), or the code is not six valid characters (`OnboardingViewModel.adopt`, `InviteCodeFormat`).

### Step 4. Accept, part 2: typing the code (phone B)

**Do.** On B's "Invite your partner", tap "Have a code?". Type A's code (lower case is fine). Tap
"Join". Keep A's app open on the invite sheet.

**See.**
- B: "joining" with a spinner, then the Today tab and the toast "You two are connected". No trial
  offer screen.
- A: close the invite sheet. Settings, Partner shows B's name and "Joined on" with today's date. The
  Us pill has two colours.
- B: Shared settings, Partner shows A's name and "Created the space".

**Time.** B up to 20 s. After accepting the share, the app waits up to 15 s for the shared space to
arrive (`JoinViewModel.spaceArrivalAttempts`, 30 tries every 500 ms). A within 30 s.

**If it fails.**
- "No space answers to that code.": a typo, or A opened the invite screen again and the code was
  replaced.
- "That code expired. Ask for a new one.": more than 15 minutes since step 2.
- "That code was already used. Ask for a new one.": the code was used before. This also happens when
  a Join failed and the screen was then left: the app keeps the used code only in memory
  (`JoinViewModel.redeemed`). Get a fresh code from A.
- "iCloud did not answer. Check that you are signed in to iCloud.": any CloudKit failure, including
  the 15 s wait running out (`JoinFailure.kind` maps every CloudKit error to this line). Tap "Join"
  again: the retry starts from the CloudKit part with the same code. If it keeps failing: iCloud Drive
  off on B, or A's share not uploaded yet (check the Dashboard: acting as A, Private database, a zone
  named `com.apple.coredata.cloudkit.share.` plus an id should exist).
- "This space already has things in it, and two spaces cannot be merged yet.": B made something
  before joining, or old Development data (section 1.1).
- "Too many tries. Wait a minute.": the redeem limit of 60 per hour per IP.
- A never shows B: bring A's app to the foreground. `PartnerChangeWatcher` compares the stored partner
  with the session on foreground and after every synced change (`AppEnvironment.reloadSessionIfPartnerChanged`).
  Still nothing after a minute: B's member did not upload.
  Dashboard, acting as A, Private database, the share zone, record type `CD_Member`: there must be two
  records.

### Step 5. Link while paired, and B's notification permission (phone B)

**Do.** Tap A's link in Messages again. On the sheet, tap "Join", then "Done". Then Tasks, plus,
What to do "B's first task", Due: "Set a date" on, "Save". Tap Allow when iOS asks.

**See.**
- The link opens a "Have a code?" sheet with the code filled in. "Join" shows "This space is already
  shared with someone." Nothing else changes, and the code is not spent: this check runs before the
  server is asked (`JoinViewModel.blockingReason`).
- "B's first task" appears on A.
- Shared settings, Notifications, "Permission" reads "Allowed" on both phones.

**Time.** The task reaches A within 5 s.

**If it fails.**
- No sheet: the route is lost between `Router.webRoute` and `RootView.consumeRoute`.
- No permission prompt: it was refused before. Fix it in iOS Settings, Notifications, Corbie.

### Step 6. Edits reach the other phone, both ways (Wi-Fi)

Both apps stay in the foreground, each on the tab being checked. Partner alerts may already show up
here. Step 9 checks them properly.

**Do and See.**
- **6a. Task, A to B, then back.** A: Tasks, plus, What to do "Milk", Who "Nobody", "Save". B: "Milk"
  under "Free" with "nobody took it yet" and "Take". B: tap "Take". A: "Milk" moves under "In
  progress" in B's colour, with a line "<B's name> took" and when.
- **6b. Date, B to A.** B: Calendar, plus, "New date", Title "Dinner", Starts this evening, "Save".
  A: "Dinner" in the Calendar on today's date.
- **6c. Wish, A to B.** A: Wishes, plus, "New wish", Title "Book", "This wish is for me" on, "Save".
  B: "Book" in Wishes.
- **6d. Plan money, both ways.** A: Plans, "Big", plus, "New plan", "With a target", Title "Trip",
  Target amount 1000, "Save". B: "Trip" in Plans. B: open "Trip", "Add money", Amount 100, "Save". A:
  "Trip" shows 100 of 1,000 in the plan's currency.
- **6e. Profile, B to A.** A: open Shared settings and stay there. B: Shared settings, section "You",
  change Name (add "2"), pick another Color, "Save". A, without leaving the screen: the Partner row
  shows the new name. A then closes the Us hub: the Us pill shows B's new colour. Then B changes the
  name back. Since fix round B the session reloads when the partner's name, colour, birthday, joined
  date or busy times switch changes (`AppEnvironment.reloadSessionIfPartnerChanged`); before it, A
  showed the change only after a relaunch.

**Time.** Each change within 5 s of Save (`docs/TEST_PLAN.md` section 5). Write down anything over
10 s.

**If it fails.**
- Nothing arrives: send the sending app to the background and back. If the change then arrives, the
  upload waited for the app. Check the Dashboard (acting as A, Private database, the share zone,
  record type `CD_TaskItem`, `CD_Event`, `CD_Wish`, `CD_Plan` or `CD_PlanExpense`). In the Dashboard
  but not on the other phone: that phone missed the silent push (pre-flight 4). Bring its app to the
  foreground or relaunch it. The sync pulls changes on launch.
- It arrives only after a relaunch: the change was downloaded but not merged into the screen
  (`PersistentHistoryObserver.process`), or that screen does not refresh on `WidgetReloadRequest`.
- Works from A to B but not from B to A: B writes into A's zone through the shared database. The
  share is created read-write (`CloudKitSharing.share`, `publicPermission = .readWrite`). Check B is
  still a participant.
- The same item twice: a duplicate import. Write down which item and on which phone.

### Step 7. The same on cellular

**Do.** B turns Wi-Fi off, cellular on. Repeat 6a with "Bread" and 6d with another 50. Then B back on
Wi-Fi, A on cellular, repeat 6b with "Lunch".

**See.** The same as step 6.

**Time.** Within 10 s. Write down anything over 30 s.

**If it fails.** Settings, Cellular, Corbie off. Low Data Mode on. The iCloud switches under
Settings, Cellular: I did not check which one CloudKit follows, so try with iCloud Drive on there.

### Step 8. Widgets update on both phones

Only the app syncs with iCloud. A widget writes into the store on its own phone, and that phone's
Corbie uploads the change the next time it runs (`PersistenceController.appGroupWithoutMirroring`,
`docs/DECISIONS.md`, persistence fix round A). This step checks both halves.

**Do.**
1. On both phones, long-press the Home Screen, add from the Corbie widgets: "Tasks" (medium), "Free
   tasks" (medium), "Our day" (large), "Days together" (small).
2. A: create task "Widget test", Who "Nobody", "Save". Go to the Home Screen on both phones. Wait
   10 s.
3. A: on A's "Tasks" widget, tap the circle next to one task that is not "Widget test". Write down
   which one and the time. Stay on the Home Screen on both phones for 60 s and watch B's widgets. Then
   open Corbie on A and write down the time.
4. B: on B's "Free tasks" widget, tap "Take" next to "Widget test". Write down the time. Stay on the
   Home Screen on both phones for 60 s. Then open Corbie on B and write down the time. Then open
   Corbie on A.

**See.**
- No "Unlock in Corbie" on any widget.
- Before 3: both "Tasks" widgets show the same open tasks in the same order: all open tasks of the
  space, earliest due date first (`WidgetDataProvider.openTasks`). "Widget test" is on both "Free
  tasks" widgets. "Days together" shows the same number on both.
- After 3: the ticked task leaves A's widget at once. For the 60 s that A stays on the Home Screen, B
  most likely still shows it: nothing on A has uploaded it yet. If B updates earlier, iOS resumed A's
  app in the background; write it down, it is not a defect.
- Within 10 s of opening Corbie on A: the ticked task is done in A's Tasks list, and it leaves B's
  Tasks list. B's "Tasks" widget follows once B's app has merged it (see the first "If it fails"
  line). The task shows once on B, never twice.
- After 4: "Widget test" leaves B's "Free tasks" widget at once. A keeps it under "Free" until B
  opens Corbie. Within 10 s of that, A's Tasks list shows "Widget test" under "In progress" in B's
  colour, and A's "Free tasks" widget drops it.

**Time.** A phone's own widget at once. The other phone's list within 10 s after the phone that
tapped the widget opens Corbie. The other phone's widget within 60 s after that, with Corbie on that
phone in the background and not force-quit: the silent push launches or resumes it, it merges the
change and asks WidgetKit to redraw (`AppDelegate` push handler, `RemotePushSync`, `WidgetReloader`).

**If it fails.**
- The other phone's widget stays old while its Corbie is in the background: look in Console for a
  `remote-push` line from that phone. No line: the push did not reach Corbie (pre-flight 4 and 17).
  A line with `noData`: the import did not bring the change in time; write down the seconds and the
  import outcome. A line with `newData` and still an old widget: WidgetKit did not redraw on
  `reloadAllTimelines`, which iOS may postpone for a widget that reloads often. Open that app and
  leave it: the widget should update. Without any of that, widgets redraw only at midnight
  (`WidgetTimelineBuilder`).
- B never gets A's tick, even a minute after A opened Corbie and stayed in it: A's app did not upload
  the widget's write. Dashboard, acting as A, Private database, the share zone, `CD_TaskItem`, the
  ticked task: `CD_isDone` still 0 confirms it. This is the path the fix changed; report it with
  both times.
- A's own Tasks list does not show the tick after opening Corbie: the app did not merge the widget's
  write (`PersistentHistoryObserver`, author `widgets`).
- The ticked or taken task shows twice on either phone: a duplicate import. Write down which and
  where.
- "Unlock in Corbie": the flag is not off on that phone (pre-flight 13). The widget reads the same
  stored flag (`WidgetDataProvider`, `MonetizationFlagStore`).
- "Nothing open." on a phone that has open tasks: the widget found no space. The App Group is missing
  on the widget target, or the extension cannot read the keychain item `apple.user.id` (access group
  `group.app.corbie`, `KeychainStore`).

### Step 8b. A wish from the share sheet (phone B)

**Do.** B: send Corbie to the background (do not force-quit it). In Safari, open any shop page, tap
Share, then "Corbie". Wait until the link is read. If the sheet reads "could not read this link -
name it yourself", type "Share test" as the name. Tap "Save". Stay out of Corbie on B for 60 s, then
open Corbie on B and write down the time.

**See.**
- The sheet is titled "Add to Corbie" and shows "reading the link" first, then the name field.
  "Save" closes it.
- A, during those 60 s: most likely no new wish, for the same reason as step 8.
- B, in Corbie: the wish is in Wishes.
- A: the wish is in Wishes within 10 s of B opening Corbie, once. A may also get the "A new wish"
  alert from step 9b.

**Time.** A within 10 s after B opens Corbie.

**If it fails.**
- "Open Corbie once to set up your space, then share again.": the extension found no member. The App
  Group or the keychain access group is missing on the share extension target.
- "could not save this one - try again": the write into the store failed on B. Write it down.
- The wish never reaches A, even a minute after B opened Corbie: Dashboard, acting as A, the share
  zone, `CD_Wish`. Not there means B's app did not upload the extension's write.
- The wish shows twice on A or B: a duplicate import.

### Step 9. Notifications reach the right person

Run each part twice: first with the receiving app in the background (Home Screen, not force-quit),
then with it in the foreground. A banner shows in the foreground too (`AppDelegate`
`willPresent` returns banner, list and sound). The phone that made the change must get nothing.
In the background the receiving phone should write a `remote-push` line (pre-flight 20) for each
change; copy it into the sheet.

**9a. Task assigned, A to B.**
- Do: A: Tasks, plus, What to do "Call the bank", Who: B's name, "Save".
- See on B: "A task for you", "<A's name> gave you Call the bank". A long press shows "Take" and
  "Done". Nothing on A.
- Then, with B locked and Corbie on B in the background: long-press the alert on B's lock screen and
  tap "Done". Do not open Corbie on B. Unlock B after a minute and open Corbie: "Call the bank" is
  done, without a second tap. A: the task leaves the open list within a minute, or only after B opens
  Corbie; write down which. The action runs without a window now (`AppDelegate.perform` waits for
  `AppEnvironment.processReady`), and whether iOS keeps Corbie running long enough to upload it is
  what this checks.
- Rule: a new task whose assignee is the reader and whose creator is not, or a task moved to the
  reader (`RemoteChangeClassifier.taskAlert`).

**9b. Partner wish, B to A.**
- Do: B: Wishes, plus, Title "Lamp", "Save".
- See on A: "A new wish", "<B's name> added Lamp". Nothing on B.
- Rule: a new wish the reader did not add, not yet gifted (`RemoteChangeClassifier.wishAlert`).

**9c. Question of the day (timed).**
- The reminder is set by the phone itself at 10:00 or 20:00 local time
  (`NotificationScheduler.scheduleQuestionReminder`), one per day, and it is cancelled once that
  person answers. The phone plans it when Today opens and when the partner's answer arrives, also
  with Corbie in the background (`PartnerProgressReminders`, triggered by a `DailyQuestion` or
  `QuestionAnswer` change from the other phone).
- If it is before 10:00 on A: put Corbie on A in the background on a tab other than Today. B answers
  today's question (Today, "Question of the day", "Answer", type, "Save"). A does not answer and
  does not open Corbie until 10:00. At 10:00, A gets "Today's question", "<B's name> has answered.
  Your turn." B gets nothing.
- Otherwise: neither of you answers today. At 20:00 both get "Today's question", "Neither of you has
  answered yet." Steps 10 to 12 do not answer the question. Run steps 13 and 14 after 20:00.
- Not a test case: if the partner answers after 10:00, the reader gets no reminder that day at all
  (open question 10). That matches the spec text of notification type 11.

**9d. Chore split ready, A finishes first.**
- Do: B opens Corbie on the Tasks tab, not Today, then goes to the Home Screen. A: Us pill, "Chore split",
  "Start the split", check the list ("Continue" needs at least 8 picked), then rate every card with
  "I actually like it", "I don't mind", "No strong feelings" or "I'd rather not" (or swipe).
- See on A: "Done. Waiting for <B's name>." and "nothing is shown until you both finish". "Ask them"
  only shows a toast; it sends nothing.
- See on B: "Chore split", "<A's name> has rated the list. Your turn." Nothing on A.
- Rule: the partner rated everything, the reader has not, and the reader was not told about this
  split before (`ChoreReminderPlanner.plan`, `corbie.chore.split.told`). It is planned when A's
  ratings arrive on B, whichever screen B was on (`PartnerProgressReminders`). Do not rate on B yet:
  step 11 continues from here.
- Then open Corbie on B, go to Today and back to the Home Screen: no second "Chore split" alert.

**Time.** The same as the change reaching the phone: within 5 s in the foreground. In the background,
write down the delay.

**If it fails.**
- Nothing in the background, but the banner shows once the app is in front: look for the
  `remote-push` line on the receiving phone. No line: iOS did not hand the push to Corbie (pre-flight
  4 and 17; iOS also rations silent pushes, so write down how many came before the first miss). A
  line with `noData` and seconds near 20: the import of the change had not finished when Corbie
  stopped waiting (open question 13). A line with `newData` and no banner: the rule said nothing;
  check the switches.
- 9c or 9d only shows up when the receiving phone opens Today: the partner's change reached the
  phone but did not plan the reminder. Write down the `remote-push` line and which case happened.
- Nothing even in the foreground: that person's switch is off (pre-flight 14,
  `RemoteChangeKind.isEnabled`), permission refused, or the reader's details were never loaded
  (`AppEnvironment.updateNotificationAudience`, called from `reloadSession`).
- The alert lands on the phone that made the change: the rule compares against the reader's member
  id. Both phones resolving to the same member points to pre-flight 9.
- Marking a task done sends nothing, by design: spec section 9 has no type for a finished task, and
  the classifier skips done tasks (`RemoteChangeClassifier.taskAlert`). `docs/TEST_PLAN.md` section 5
  step 6 says the same since fix round B.

### Step 9e. A phone whose Corbie is not in memory

This is the path fix round B changed: iOS launches Corbie in the background for the push, with no
window, and the app must still merge, alert and redraw the widgets. It cannot be run on a simulator.

**Do.**
1. B: open Corbie once, then restart the phone (hold the side button, slide, switch on again). Unlock
   B once and leave it on the Home Screen with the "Free tasks" widget from step 8 visible. Do not
   open Corbie on B.
2. A: Tasks, plus, What to do "Cold start", Who: B's name, "Save".
3. Wait 60 s. Then, still without opening Corbie on B, look at B's lock screen and widget.
4. Lock B. A: Tasks, plus, What to do "Cold start 2", Who "Nobody", "Save". Wait 60 s.

**See.**
- B, after 2: "A task for you", "<A's name> gave you Cold start", within a minute, while Corbie was
  never opened after the restart.
- Console on B: one `remote-push` line for the shared store with `newData`.
- B, after 4: no alert (a free task alerts nobody), and "Cold start 2" appears on B's "Free tasks"
  widget within a minute, with B locked.
- Then open Corbie on B: Today loads as usual, the tasks are there once, and no alert repeats.

**Time.** Within 60 s of A's save. Write down the seconds from the `remote-push` line.

**If it fails.**
- No alert and no `remote-push` line: iOS did not launch Corbie for the push. Check pre-flight 4, and
  that Corbie was opened once after installing. Try once more with B unlocked.
- A `remote-push` line with `import timedOut` and `noData`, and the alert shows only when Corbie is
  opened: the import started before Corbie began waiting and finished too late, or not at all, in the
  background (open question 13). Write down the seconds.
- The alert shows but the widget stays old: as step 8, "If it fails".
- Opening Corbie on B afterwards shows the intro screen instead of the tabs: the background launch
  read no signed-in member and the window did not load it again (`AppEnvironment.bootstrap`). Stop
  and report it with the time of the restart and of the first unlock.

### Step 10. Question of the day is the same in two time zones

**Do.**
1. Both phones: Today, the "Question of the day" card. Compare the question text.
2. B: iOS Settings, General, Date & Time, "Set Automatically" off, Time Zone: pick a city where the
   date differs from A's date right now. After noon on A, pick Auckland. Before noon on A, pick
   Honolulu.
3. Switch back to Corbie on B. It reloads the card when it becomes active. Compare again.
4. B: turn "Set Automatically" back on.

**See.** The same question text on both phones, before and after the change. The status lines ("You
are still writing", "<name> is still writing") do not change.

Why: the day is counted in the space's time zone, taken from A's phone when A created the space
(`Space.anchorTimeZone`, `QuestionSelector.dayKey`), not in the phone's zone.

**Time.** At once.

**If it fails.**
- Different questions right after pairing, before any zone change: both phones created the day's
  question before syncing. Wait a minute and reopen Today. Both should settle on one question
  (`CoreDataQuestionRepository.merged` keeps the record with the lowest id). Still different: the
  records did not sync. Dashboard, share zone, `CD_DailyQuestion`: one record for today.
- Same before, different after: B's copy of the space has no time zone and falls back to the phone's
  (`SpaceDTO.anchorCalendarTimeZone`). Dashboard, `CD_Space`, field `CD_anchorTimeZone`.
- No card at all: no question fits the pair's stage (`QuestionSelector.selection`), or the phones use
  different languages.

### Step 11. Chore ratings stay hidden until both finish

Starts where 9d ended: A rated everything, B has not.

**Do.**
1. B: Today, card "Rate the chore list." with "nobody sees your answers yet". Open it and rate about
   half the cards. Stop.
2. Look on both phones: Today, Us pill, "Chore split".
3. B: rate the rest.
4. On one phone: "See the split". Then "Add these to Tasks".

**See.**
- Before B finishes: no line on either phone says what the other person chose. Such lines ("<name>
  doesn't mind.", "<name> would rather not.") exist only on the reveal screen. A shows "Done. Waiting
  for <B's name>.".
- After B finishes: both phones show "You two are both done." and "nothing has been shared yet" with
  "See the split". The Today card reads "You two have both rated." with "the split is waiting".
- After "See the split": "You two agree more than you thought.", lists "Yours", "<name>'s",
  "Rotating", "Whoever's around", and the lines about what each of you said. The other phone shows
  the same within seconds.
- After "Add these to Tasks": "Added to Tasks", and the chores appear in Tasks on both phones with
  "from the chore split".

**Time.** Each change within 5 s on the other phone.

**If it fails.**
- A choice of the other person shows before both finish: the filter is
  `ChoreItemDTO.init(_:title:showsEveryRating:viewerMemberId:)`, switched by
  `CoreDataChoreRepository.everyoneHasRated`.
- B finished but a phone stays on "Waiting for": one phone's ratings did not sync (Dashboard,
  `CD_ChoreRating`), or that phone sees fewer than two members in the space (`everyoneHasRated` counts
  `space.members`).
- "See the split" answers "Check what you typed.": the reveal needs two members and both ratings on
  every included chore (`CoreDataChoreRepository.reveal`).
- Note, not a defect: the ratings are ordinary records in the shared zone (`CD_ChoreRating`, field
  `CD_verdictRaw`). "Hidden" is a rule of the app, not encryption.

### Step 12. Free time and the privacy audit

**12a. Turn sharing on (both phones).**

**Do.** A first: Us pill, Shared settings, Privacy, "Share my busy times" on. Allow full calendar
access. Then Calendar tab, the clock button at the top ("When you two are free"). The first time, a
sheet "Your calendar stays yours" shows; tap "Share my busy times" or "Not now". Leave A on that
screen. Then the same on B. Write down what A's screen shows. Then force-quit Corbie on both phones,
open it again, and open the same screen.

**See.**
- A, before B switches: "<B's name> hasn't shared their busy times yet".
- A, within a few seconds of B's switch, without touching A: "Free windows" with a list. The
  session follows the partner's switch as it syncs (`AppEnvironment.reloadSessionIfPartnerChanged`,
  `PartnerChangeRule`) and the screen reloads when the partner changes (`FreeTimeView`).
- After the relaunch, the same on both. "Evenings", "Weekends" and "2+ hours" narrow the list. "Next
  7 days" and "Next 14 days" switch the range.

**Time.** The list within a few seconds of opening.

**If it fails.**
- "Corbie needs your busy times too": that phone's own switch is off.
- "Corbie has no access to your iPhone calendar.": calendar access refused. iOS Settings, Privacy,
  Calendars.
- "<partner> hasn't shared their busy times yet" after the relaunch: the partner's `sharesBusyTimes`
  did not sync. Dashboard, `CD_Member`, field `CD_sharesBusyTimes`.
- The list shows after the relaunch but not before it: the partner's switch synced but the session
  did not pick it up. Write down how long A stayed on the screen.
- A new iPhone Calendar event shows up only after about 30 s: changes are batched for 30 s
  (`BusyPublisher.changeDebounce`). Pull down on the free time screen to publish at once.

**12b. Read the records in the Dashboard.**

1. `https://icloud.developer.apple.com`, sign in with the team Apple ID, CloudKit Database, container
   `iCloud.app.corbie`, environment **Development**.
2. Schema, Record Types, `CD_BusyInterval`. Read the list of fields. This is the place to read,
   because a field that is always empty still shows up here.
   - Allowed, from the model (`CorbieModel.swift` lines 149 to 154, `BusyInterval.swift`): `CD_id`,
     `CD_memberId`, `CD_startAt`, `CD_endAt`, `CD_sourceRaw` (value `device` for the iPhone calendar,
     `corbie` for Corbie's own dates), `CD_updatedAt`, `CD_space` (the link to the space record),
     `CD_entityName` (value `BusyInterval`). CloudKit adds its own system fields: record name,
     created and modified time and user, change tag.
   - Not allowed: anything else. No title, location, notes, URL, attendee, organizer, calendar name or
     event identifier.
   - `docs/TEST_PLAN.md` 5a mentions an all-day flag. The model has none: an all-day event is stored
     as whole days from start to end (`BusyIntervals.wholeDays`).
3. Data, Records. "Act as iCloud Account" with A's Apple ID. Database: **Private**. Zone: the one
   named `com.apple.coredata.cloudkit.share.` plus an id. The shared space moved there in step 2;
   `com.apple.coredata.cloudkit.zone` holds only what was never shared. Record type
   `CD_BusyInterval`. Query.
4. If the Dashboard refuses the query because `recordName` is not queryable: Schema, Indexes,
   `CD_BusyInterval`, add an index on `recordName` of type Queryable, save, query again. This changes
   the Development schema only and is harmless in a later deploy.
5. Records from both phones sit in this one zone: B writes into A's zone through the shared database.
   To tell the people apart, query `CD_Member` in the same zone: its `CD_id` equals `CD_memberId`, and
   `CD_displayName` names the person. As B's Apple ID, the same zone appears under Database:
   **Shared**.
6. Open at least three records per person. Each holds two dates, a member id, `device` or `corbie`,
   an update time and a link to the space. None of the titles, places or guests from pre-flight 15
   appears anywhere.
7. Expect `corbie` records for both people covering the same shared dates, such as "Dinner" from
   step 6b: each phone publishes the space's own dates of kind Event and Trip as its own busy time
   (`CorbieEventBusyPublisher`).
8. Screenshot the field list and the record list.

**12c. Turn it off and watch the records go (phone A).**

**Do.** A: Shared settings, Privacy, "Share my busy times" off. Keep A's app in the foreground. In the
Dashboard, query again every 5 s. On B, look at the free time screen, pull down, then force-quit and
reopen Corbie and look again.

**See.**
- Dashboard: every `CD_BusyInterval` with A's member id is gone. B's records stay. Screenshot the list.
- B, as the spec asks (`docs/TEST_PLAN.md` 5a step 5): "<A's name> hasn't shared their busy times
  yet" within 60 s, before the relaunch as well as after it. B's session follows A's switch as it
  syncs (step 12a).

**Time.** "Within seconds" is the target from module 21. The app deletes the records on the phone at
once (`BusyPublisher.disableSharing`, `CoreDataBusyIntervalRepository.deleteAll`) and the upload
follows the save. Not measured. Over 60 s with A in the foreground is a defect.

**If it fails.**
- Records stay: A's app went to the background right after the switch, so the upload is waiting.
  Bring it back and wait. Or the switch did not save (toast "That did not save.").
- Only A's `corbie` records stay: a publish ran after the switch. `deleteAll(memberId:)` removes both
  kinds; `publishBusyTimes` reads the switch from the session.
- A title, place or guest field exists: stop and report it. The calendar reader takes only start,
  end, all-day, availability, and the reply of the phone's own owner to skip declined events
  (`SystemDeviceCalendarSource.busyRanges`). The writer sets only the fields listed above
  (`CoreDataBusyIntervalRepository.replace`). An extra field means another build wrote it.

Optional, if there is time before step 13: `docs/TEST_PLAN.md` section 5 steps 8 (capsule), 9 (vote),
11 (Us badge) and 5b (Today and the Our day widget). Their expectations stand as written there.

### Step 13. Leave the space (phone B)

**Do.**
1. A: Us pill, Shared settings, Account. Look at the rows. Leave A's app open on this screen, scrolled
   to the Partner section.
2. B: Us pill, Shared settings, Account. Look at the rows. Tap "Leave space". The dialog reads "Leave
   this space?" and "You stop seeing the shared data. Your partner keeps it." Tap "Leave space".
3. Do not touch A for 60 s. Then write down what A's Partner section shows.
4. A: Tasks tab.

**See.**
- A, in 1: only "Delete account". No "Leave space": an owner is never offered it
  (`SettingsAccountPlan.offersLeaving`).
- B, in 2: "Leave space" and "Delete account".
- B: a spinner in the row for a few seconds, up to about 20 s, then the intro screen "A shared space
  for two". B first removes its own member record and waits for that removal to upload
  (`CloudKitSharing.leave`, `CloudKitSharing.memberExportTimeout`), then leaves the share. Pending
  Corbie notifications on B are cancelled. B's widgets show their empty state after the next reload.
- A, within 60 s, without touching the phone: Partner reads "Nobody yet. The space works solo.",
  followed by "Invite your partner" and "Have a code?". The Us pill shows one colour. Everything else
  stays.
- A, in 4: every task that was B's, for example "Call the bank" from 9a and "Widget test" from step
  8, is under "Free" with "nobody took it yet". Plan steps that were B's are free too.
- Dashboard, acting as A, Private, the share zone: `CD_Member` holds one record, A's. B's other
  records (dates, wishes, busy times) are still there, as "Your partner keeps it" says. Acting as B,
  the Shared database no longer lists the zone.
- B: Sign in with Apple again. A new solo space with nothing of A's.

**Time.** B back on the intro screen within 25 s. A shows "Nobody yet" within 60 s.

**If it fails.**
- Toast "iCloud did not answer." at once, and B stays in the tabs still paired: B could not reach
  iCloud, and nothing was changed (the share is checked before anything is removed). Fix the network
  and tap "Leave space" again.
- Toast "iCloud did not answer." after the spinner, and B stays in the tabs: leaving the share failed
  after B's member record was already removed (`docs/KNOWN_ISSUES.md`, "Leaving can stop halfway").
  Tap "Leave space" again before doing anything else. Write it down.
- The spinner runs about 20 s: the upload of B's removal was not confirmed in time. Leaving goes on
  anyway, and A must then remove B by itself (next line). Write down which of the two happened.
- A still shows B after 60 s: send A's app to the background and bring it back, which runs the
  owner's check (`AppEnvironment.reconcilePartnerMembership`). Still B: relaunch A. Still B after the
  relaunch: Dashboard, acting as A, the share zone. Two `CD_Member` records means B's removal never
  uploaded; then open the `cloudkit.share` record and write down whether B is still listed as a
  participant. The owner's check removes B only when no one but A is accepted or pending.
- A shows "Nobody yet" but B's tasks are not free: the tasks were not in the same upload as the member
  removal (`MemberRepository.removeMembersAndFreeTheirTasks`).
- B lands on onboarding but A's data shows up again after signing in: the zone was not cleared on B
  (`purgeObjectsAndRecordsInZone`).

### Step 13b (optional). The owner removes a partner who left without a trace

This checks the owner's own cleanup, which step 13 only needs when B's upload fails. Run it only if
the Dashboard lets you delete a zone from the Shared database; I have not checked that it does.

**Do.** Pair again: A: Shared settings, Partner, "Invite your partner", "Share code". B, signed in
with its empty solo space from step 13: tap the link in Messages, then "Join". Wait until A shows B
as partner. Then, with both apps in the background: Dashboard, "Act as iCloud Account" with B's Apple
ID, Database: Shared, delete the zone named `com.apple.coredata.cloudkit.share.` plus an id. That
takes B out of the share and leaves B's `CD_Member` record in A's zone. Then bring A's app to the
foreground and open Shared settings. Afterwards, delete Corbie on B and install it again before step
15, because nothing on B was told about the removal.

**See.** Within a few seconds: Partner reads "Nobody yet. The space works solo." with the invite
rows, and B's tasks are free (`CloudKitSharing.removeDepartedMembers`, `DepartedMemberRule`).
Dashboard, acting as A, the share zone: one `CD_Member` record.

**If it fails.** A still shows B: relaunch A with the network on. Still B: open the `cloudkit.share`
record acting as A and write down every participant with its acceptance status. A pending or accepted
participant other than A keeps B on purpose.

### Step 14. The owner deletes the space (phone A)

**Do.** A: Us pill, Shared settings, Account, "Delete account". The dialog reads "Delete your
account?" and "The space you own goes with it, this phone is wiped and you are signed out. There is no
undo." Tap "Delete account". Wait for the intro screen. Then check the Dashboard. Then on A: Sign in
with Apple again with the same Apple ID.

**See.**
- A: a spinner, then the intro screen, with no toast when the three Apple secrets were set before A
  signed in. Without them there is no refresh token and no revoke call (section 3). Widgets on A go
  empty after the next reload.
- Before signing in again, iPhone Settings, your name, Sign in with Apple: Corbie is no longer listed.
  If it is, the revoke failed: note the toast, if any.
- Dashboard, acting as A, Development, Private: the zone `com.apple.coredata.cloudkit.share.` plus an
  id is gone. `com.apple.coredata.cloudkit.zone` is gone, or back but empty once A's app has started
  again. Query `CD_Space`, `CD_Member` and `CD_TaskItem` and write down the counts: 0 each. Before
  wiping the phone, the app deletes these zones on the server itself
  (`CloudKitSharing.purgePrivateZones`), so this does not depend on an upload finishing in time.
- After signing in again: a fresh solo space, an empty profile apart from the Apple name, "Nothing on
  today". Nothing from before comes back.

**Time.** A back on the intro screen within 20 s.

**If it fails.**
- Toast "iCloud did not answer." and A stays in the tabs: at least one zone was not deleted on the
  server (`CloudKitSharing.purgePrivateZones`), so the deletion stopped before the wipe. Check the
  network and tap "Delete account" again. If it keeps failing, write down which zones the Dashboard
  still shows.
- Old data after signing in again: the same, look at the zones in the Dashboard.
- A stays in the tabs: `wipeLocalState` did not finish. Relaunch.

### Step 15 (optional). Pair again through the link

Only if step 14 left A with an empty space.

**Do.** A: Shared settings, Partner, "Invite your partner", "Share code". B, signed in with an empty
solo space since step 13: tap the new link in Messages, then "Join".

**See.** A "Have a code?" sheet with the code filled in, then the same as step 4. This is the full
link-to-join path that step 3 stopped short of.

**If it fails.** "This space already has things in it, and two spaces cannot be merged yet.": B made
something after step 13. Otherwise as in steps 3 and 4.

### Step 16 (optional). The partner deletes the account (phone B)

Only if step 15 paired the phones again.

**Do.** Leave A's app open on Shared settings. B: Us pill, Shared settings, Account, "Delete
account", then "Delete account" in the dialog. Wait for the intro screen. Then check the Dashboard.
Then on B: Sign in with Apple again.

**See.**
- B: a spinner, up to about 20 s for leaving plus the zone deletion and the Apple revoke, then the
  intro screen.
- The dialog on B still says "The space you own goes with it", although B owns nothing. The code
  deletes only B's part (`SettingsViewModel.deleteAccount`); the wording is a known copy problem, not
  a data problem.
- A, within 60 s: "Nobody yet. The space works solo." with the invite rows. A keeps all data, and B's
  tasks are free, as in step 13.
- Dashboard, acting as B: Shared no longer lists A's zone. Private has no
  `com.apple.coredata.cloudkit.` zone with records in it.
- B after signing in again: a fresh solo space with nothing from before.

**If it fails.** As in steps 13 and 14. Toast "iCloud did not answer." with B still in the tabs means
leaving or the zone deletion failed and nothing was wiped. Tap "Delete account" again; it finishes a
half-done leave. If it keeps failing, check both Dashboard views and write down what is left.

---

## 5. Not in this session

- `docs/TEST_PLAN.md` section 5 step 4 (one subscription for two), sections 7 and 8: monetization is
  off.
- `docs/TEST_PLAN.md` section 6 (offline and reconnect): a separate session.

---

## 6. Open questions found in the code while writing this plan

None of these was run on a device. Each one names the step where it shows.

1. **Fixed in the persistence fix round A: leaving did not remove the partner from the owner's
   space** (steps 13 and 13b). B now removes its own `Member` record and frees its tasks before
   leaving (`CloudKitSharing.leave`), and A removes members of a space whose share has no other
   accepted or pending participant (`CloudKitSharing.removeDepartedMembers`, `DepartedMemberRule`).
   A partner who only deletes the app is still a participant and stays (`docs/KNOWN_ISSUES.md`).
2. **Fixed in fix round B: the partner's details were loaded only at launch** (steps 12a and 12c).
   The session now reloads whenever the stored partner differs from the session's partner in a field
   the app shows (`AppEnvironment.reloadSessionIfPartnerChanged`, `PartnerChangeRule`), after every
   synced change and on foreground, and the free time screen reloads when the partner changes.
3. **Fixed in the persistence fix round A: deleting the account could leave the records in iCloud**
   (steps 14 and 16). The app now deletes the zones on the server before the wipe
   (`CloudKitSharing.purgePrivateZones`), and a participant leaves first as in step 13.
4. **Fixed in the code, not yet on a device: revoking Sign in with Apple used a code Apple accepts only
   once and only for five minutes.** The app now sends the code to `POST /session` at sign-in, stores
   the refresh token the server returns (`AppEnvironment.exchangeSessionToken`) and revokes with that
   token on deletion (`SettingsViewModel.revokeApple`). Check in step 14 that Settings, Apple ID,
   Sign in with Apple no longer lists Corbie after the deletion.
5. **Fixed in the persistence fix round A: the widget and share extensions each ran their own
   CloudKit sync on the same files** (steps 8 and 8b). They now open the files without syncing
   (`PersistenceController.appGroupWithoutMirroring`) and the app uploads what they wrote, so their
   changes reach the partner after the app next runs (`docs/KNOWN_ISSUES.md`).
6. **Fixed in the persistence fix round A: the owner saw "Leave space"** (step 13). The row now shows
   only for the participant (`SettingsAccountPlan.offersLeaving`).
7. **Fixed in the code in fix round B, not yet on a device: partner alerts and widget redraws needed
   the receiving app in memory** (steps 8, 8b, 9 and 9e). The app delegate now owns the environment
   and starts the widget reloader, the session with its alert audience and the change notifier from
   `didFinishLaunching` (`AppEnvironment.startProcess`), and the push handler waits for the import
   and the alerts before it answers iOS (`RemotePushSync`). The chore notice and the question
   reminder are planned from partner changes too (`PartnerProgressReminders`), not only by the Today
   cards.
8. **A used invite code is kept only in memory** (step 4). `JoinViewModel.redeemedShare`
   (`JoinViewModel.swift` lines 111 to 116): if the CloudKit part fails and the screen is closed, the
   code is spent and a new one is needed. Every CloudKit failure, including the 15 s wait, reads "Check
   that you are signed in to iCloud." (`JoinFailure.swift` line 19), which misleads when the account is
   fine.
9. **Fixed in fix round B: `docs/TEST_PLAN.md` disagreed with the code.** 5a now lists the
   `BusyInterval` fields from `CorbieModel.swift`, with no all-day flag. Section 5 step 6 now expects
   no alert for a task marked done, which is what spec section 9 lists and what the classifier does.
   Section 5 step 12 expects "Nobody yet" on A, which the code does since round A (see 1).
10. **The question reminder can disappear for the day.** When the partner answers after 10:00,
    `scheduleQuestionReminder` cancels the pending 20:00 reminder and the 10:00 one is already past
    (`NotificationScheduler.swift` lines 395 to 398). It follows the spec text of type 11, so this is a
    product question.
11. **The app delegate's share-accept callback is likely never called.**
    `application(_:userDidAcceptCloudKitShareWith:)` (`CorbieApp.swift` lines 96 to 109) is the
    pre-scene API; a SwiftUI app gets the scene version instead. The invite flow does not use it
    (`JoinViewModel` accepts the share itself), so only someone opening a raw iCloud share link is
    affected.
12. **The delete dialog tells a participant that "The space you own goes with it"** (step 16). There
    is one message for both roles (`SettingsConfirmation.messageKey`, `settings.account.delete.note`).
    For B the code only removes B's own part and leaves A's space alone, so the sentence is wrong for
    B. Fixing it needs a second catalog key in five languages.
13. **When the container's import starts relative to the push callback is not known** (steps 8, 9
    and 9e). The push handler waits up to 20 s for an import of the pushed database that was running
    when the push arrived or started after it (`RemotePushSync`, `CloudKitRunningImports`). If
    `NSPersistentCloudKitContainer` finishes its import before Corbie hears about the push, the wait
    runs the full 20 s and the change is still classified, only later than it could be. If it starts
    the import only after Corbie has answered iOS, the alert may wait for the next launch. The
    `remote-push` line (pre-flight 20) shows which one happens.
14. **The notification prompt can be asked from a background launch.** The first change from the other
    phone asks for permission when it was never asked (`RemoteChangeNotifier.noteJointAction`), and
    that can now happen with Corbie in the background. What iOS does with that request then is not
    checked. This session does not reach it, because both phones answer the prompt in steps 1 and 5.

---

## 7. What to record

One row per check. Add a screenshot when a step is slower than its target or shows something else
than its "See" lines.

| Step | Phone | Action at | Seen at | Delay | Pass | Notes, screenshot |
| --- | --- | --- | --- | --- | --- | --- |
| | | | | | | |

Also note once per session: the commit and local changes of the build (pre-flight 6), iOS versions,
the network each phone was on, the Developer screen's "Monetization" footer on both phones, and every
`remote-push` line from steps 8, 9 and 9e (pre-flight 20).
