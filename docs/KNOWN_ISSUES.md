# Known issues

Found in the QA pass and not fixed there. Anything fixed in that pass is in `docs/DECISIONS.md`
instead. Severity: **blocker** stops a submission, **major** ships a broken feature, **minor** is
wrong but survivable.

Last checked against the build in this worktree on 2026-09-06, Xcode 26.6, iOS 26.5 runtime, on
iPhone 17 Pro Max QA, iPhone 17e QA and iPhone 17 Badge.

## Blockers

### The app has no icon

`Corbie/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` declares one universal 1024x1024
slot and the folder contains no image file, so the build has no icon and App Store Connect rejects
the upload.

Reproduce: `ls Corbie/Resources/Assets.xcassets/AppIcon.appiconset/` lists `Contents.json` and
nothing else.

Fix: export the two-raven mark at 1024x1024 into that `.appiconset`. The mark already exists as a
vector view, `CorbieMarkView` in `Packages/CorbieCore/Sources/CorbieCore/Design`, and it is what the
onboarding intro draws, so the icon can be rendered from it rather than redrawn.

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

### Free time and half the Us badge cannot be finished by one person

A solo space can raise the badge dot from an unanswered vote it created itself
(`CorbieUITests/UsBadgeUITests`), from an unopened capsule, and from a person whose birthday falls
inside fourteen days with no gift picked (`CorbieUITests/QAUsBadgeUITests`). The two remaining
triggers in `UsBadgeRule` need a partner: a wish added by the partner, and a gift not picked for the
partner's own birthday or the anniversary, which `RadarService.partnerStatus` reads from the partner's
wishes. The same holds for free time: `FreeTimeView` shows "Free time needs two calendars" without a
partner, so the slot list, the filters and the "Ask them" path are two-Apple-ID checks
(`docs/TEST_PLAN.md` section 4).

## Цены на экранах оплаты не проверяются автотестом

`CorbieUITests/PaywallScreensUITests` доходит до `TrialOfferView` и `ComparisonView` и проверяет их тексты, но не карточки с ценами: в прогоне через `xcodebuild test` StoreKit не подхватывает `Products.storekit`. В логе симулятора клиент уходит в Sandbox (`Requesting Media API product batch ["app.corbie.monthly", "app.corbie.yearly"]`) и запрос падает без сети, экран показывает `The App Store did not answer`. XcodeGen 2.46 умеет класть `storeKitConfiguration` только в Run-действие схемы, ручная правка `Corbie.xcscheme` не помогает и стирается генерацией.

Что это значит: арифметику годовой цены и скидки держат юнит-тесты `CorbieTests/PaywallScreensTests`, а карточки цен проверяются руками запуском из Xcode (Run-действие схемы StoreKit-конфигурацию подхватывает).

