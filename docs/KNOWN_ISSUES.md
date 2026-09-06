# Known issues

Found in the QA pass and not fixed there. Anything fixed in that pass is in `docs/DECISIONS.md`
instead. Severity: **blocker** stops a submission, **major** ships a broken feature, **minor** is
wrong but survivable.

Last checked against the build in this worktree on 2026-09-06, Xcode 26.6, iOS 26.5 runtime.

## Blockers

### German, Spanish, French and Italian print the catalog key on screen

The four non-English tables are 107 keys short of English, and a key that is missing from a
`<lang>.lproj/Localizable.strings` does not fall back to English: `String(localized:)` returns the
key itself. The German tab bar reads `tab.today.title`, not `Today` and not `Heute`. Eight further
keys carry an entry with an empty value, which renders as nothing at all.

Reproduce:

```
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max QA' \
  -derivedDataPath /tmp/corbie-dd-qa build
cd /tmp/corbie-dd-qa/Build/Products/Debug-iphonesimulator/Corbie.app
python3 - <<'PY'
import json, subprocess
load = lambda l: json.loads(subprocess.run(
    ['plutil','-convert','json','-o','-', f'{l}.lproj/Localizable.strings'],
    capture_output=True, text=True).stdout)
en = load('en')
for l in ['de','es','fr','it']:
    t = load(l)
    print(l, 'missing', len([k for k in en if k not in t]),
             'empty', len([k for k,v in t.items() if v == '']))
PY
```

prints `de missing 107 empty 8` and the same for the other three. In the app: launch with
`-AppleLanguages (de) -AppleLocale de_DE` and the first tab is labelled `tab.today.title`.

The missing keys are the ones added after the localization pass: everything under `today.`,
`freetime.`, `recap.`, `plans.step.`, `plans.detail.steps`, `people.date.`, `us.pill.label.new`,
`tab.today.title`. The empty ones are `plans.detail.action.addexpense`, `plans.detail.expenses`,
`plans.detail.expenses.empty`, `plans.detail.expenses.note`, `plans.editor.field.saved.hint`,
`plans.expense.field.note.placeholder`, `plans.expense.info`, `plans.expense.title`.

Fix, in the localization module: fill the 107 keys in `Corbie/Resources/Localizable.xcstrings` and
give the 8 empty ones a value. `scripts/check_translations.sh` is the gate and currently reports 468
entries. Until it passes, do not ship a localised App Store listing, and do not trust any German
screenshot.

`CorbieUITests/LocalizationUITests` skips a language whose tab titles are missing and names the keys
in the skip reason, so the suite goes green on its own once the catalog is filled.

### The app has no icon

`Corbie/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` declares one universal 1024x1024
slot and the folder contains no image file, so the build has no icon and App Store Connect rejects
the upload. Fix: export the two-raven mark from `docs/02_BRAND_BOOK.md` section 2 at 1024x1024 into
that `.appiconset`.

### The server base URL is never configured

`ServerConfiguration.infoPlistKey` is `CORBIE_SERVER_URL`
(`Packages/CorbieCore/Sources/CorbieCore/Services/APIClientConfiguration.swift:4`) and no Info.plist
in the project sets it: `grep -rn CORBIE_SERVER_URL --include='*.yml' --include='*.plist' .` finds
only the declaration. Every client call therefore goes to `https://corbie.supabase.co/functions/v1`
(`ServerConfiguration.fallback`, `:36`), a placeholder project ref.

Effect today: invites cannot be created or redeemed, links never parse, currency rates never refresh,
the entitlement can only come from the local StoreKit transaction, and analytics never lands. Each
degrades into a hint rather than a crash (`docs/TEST_PLAN.md` section 2), so it is invisible until
someone tries to pair.

Fix: add `CORBIE_SERVER_URL` to the Corbie and CorbieShare Info.plist blocks in `project.yml` with the
real Supabase project ref, per build configuration. `SessionService` already refuses to call a
placeholder (`Corbie/Features/Pairing/SessionService.swift:26`); `APIClient` does not, and could get
the same guard so the failure names the cause instead of a network error.

## Minor

### An automated run can never show a StoreKit price on the paywall

`Products.storekit` is attached to the Run action only, so `xcodebuild test` opens the paywall with no
products and it renders `paywall.state.unavailable` ("The App Store did not answer") instead of the
two offers. `QAAppearanceUITests.testThePaywallShowsWhatAppReviewLooksFor` therefore asserts the
headline, Restore, the two legal links and the auto-renew sentence, then skips the price and period
check with that reason.

This is not a project.yml oversight: XcodeGen 2.46 emits `StoreKitConfigurationFileReference` for the
Run action only. Setting `storeKitConfiguration` under `schemes.Corbie.test` is accepted and silently
dropped, which is why it is not there.

Fix: add a `Corbie.xctestplan` carrying `storeKitConfigurationFileReference` and point
`schemes.Corbie.test.testPlans` at it. Until then the price is a manual check
(`docs/TEST_PLAN.md` section 8).

### Navigation bar items are 36 points tall

`UsPill` asks for `.frame(minWidth: 44, minHeight: 44)`
(`Packages/CorbieCore/Sources/CorbieCore/Design/Components/UsPill.swift:22`) but inside a
`ToolbarItem` the bar constrains it: XCUITest reports the pill's frame as `{{343, 66}, {73, 36}}` on
iPhone 17 Pro Max, and the toolbar Save button as 36 points tall too. Whether the system still hands
those items a 44 point touch region was not measured, so `QATapTargetUITests` checks only the
controls the app lays out itself (filter chip, Take, Who segment, due toggle, Today checkbox,
appearance segment) and leaves the bar items out.

Reproduce: any UI test, `print(app.usPill.frame)` after `launchSignedIn()`.

Fix, if the founder wants the pill visually bigger: give it its own row instead of a toolbar item, or
accept the bar height. Nothing to change if the system region is enough.

### A completely empty Today hides the plans carousel

The revision says every block without data is hidden except the plans strip, which shows one
"Add a plan" card. That holds while any other block has data
(`CorbieUITests/TodayUITests` proves it), but when the whole feed is empty `TodayView` draws the
module 16 empty state instead of the blocks (`Corbie/Features/Today/TodayView.swift:44`), and that
state offers Add a task, Add a date and Invite your partner, with no way to start a plan.

Reproduce: fresh install, do not add anything, open Today. Screenshot `tab0_today`.

Fix, for the founder to decide: either keep the empty state and give it a fourth action, or keep the
carousel above the empty state so the "Add a plan" card is always there. Both need a new catalog key
if the empty state gains an action.

### The Us counters still show a dash when there is nothing to count

`UsHubView.counterColumn` renders `Text(value.map { $0.formatted() } ?? "-")` in the 56pt counter
font (`Corbie/Features/Us/UsHubView.swift:108`). On a new space with no together-since date and no
upcoming date, both columns render a hyphen at counter size.

Reproduce: fresh install, skip the together-since date in onboarding, open the Us hub. Screenshot
`us_hub` from the QA run.

Fix, for the founder to decide: drop the number entirely when there is nothing to count and let the
mono caption carry the state, which is what `us.counters.empty` already says.

### A list item exposes two buttons with the same VoiceOver label

`ListItemRow` builds a checkbox button labelled with the item title
(`Corbie/Features/Plans/Lists/ListItemRow.swift:34`) and a details button whose label is the same
title (`:75`). VoiceOver announces "Milk, button" twice in a row and only the value ("ticked" / "not
ticked") tells them apart. Fix: give the details button its own label, for example the item title
plus its note, or fold the two into one element with a custom action.

### The primary button is not the accent colour

`CorbiePillButtonStyle(variant: .filled)` fills with `CorbieColorPalette.text` and writes in `bg`
(`Packages/CorbieCore/Sources/CorbieCore/Design/Components/PillButtonStyle.swift:27` and `:34`), so
every primary call to action is a black pill on light and a white pill on dark. The brand book names
`ice` `#8FC5E8` as the single accent, "buttons, progress, selections, active tab", and chips, the
progress bar and the active tab do use it. This is a deliberate-looking design system choice from
module 01, so it needs the founder to decide rather than a silent change.

### The rating prompt from the spec does not exist

Spec section 12 asks for `SKStoreReviewController` after the third joint action and not before day
five. `grep -rn "requestReview\|SKStoreReviewController" Corbie Packages/CorbieCore/Sources` returns
nothing.

### Notifications are asked for once and never re-offered in the app

If the first request is denied, the only route back is Settings, Notifications, "Open iOS Settings".
That is a real route and there is no dead end
(`QAPermissionsUITests.testDeniedNotificationsAreReportedInSettingsWithAWayBack`), but nothing in the
feature screens hints that a reminder was not scheduled: `TaskDueNotifications` and the capsule
editor swallow the refusal silently. Worth a one-line hint next to the due date toggle once someone
has denied.

### Free time and the Us badge cannot be finished by one person

A solo space can raise the badge dot from an unanswered vote it created itself
(`CorbieUITests/UsBadgeUITests`) and from an unopened capsule, but the two remaining triggers in
`UsBadgeRule` need a partner: a wish added by the partner and a gift not yet picked for a partner
date. The same holds for free time: `FreeTimeView` shows "Free time needs two calendars" without a
partner, so the slot list, the filters and the "Ask them" path are two-Apple-ID checks
(`docs/TEST_PLAN.md` section 4).
