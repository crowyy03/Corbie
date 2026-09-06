# Known issues

Found in the QA pass on 2026-09-06 and not fixed there. Anything fixed in that pass is in
`docs/DECISIONS.md` instead. Severity: **blocker** stops a submission, **major** ships a broken
feature, **minor** is wrong but survivable.

## Blockers

### German, Spanish, French and Italian render as empty strings

The app declares five languages and ships four of them empty. `Corbie/Resources/Localizable.xcstrings`
holds 781 keys; 377 of them carry a `de`, `es`, `fr` and `it` entry, and every one of those entries is
`{"state": "new", "value": ""}`. Xcode compiles them, so the built app has the keys present with an
empty value and `String(localized:)` returns the empty string instead of falling back to English.

Reproduce:

```
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 17 Tests' \
  -derivedDataPath /tmp/corbie-dd-qa build
plutil -convert json -o - \
  /tmp/corbie-dd-qa/Build/Products/Debug-iphonesimulator/Corbie.app/de.lproj/Localizable.strings \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d), sum(1 for v in d.values() if v==""))'
```

prints `373 373`. In the app: launch with `-AppleLanguages (de) -AppleLocale de_DE` and the tab bar,
every Save and Cancel button and half the screens have no text at all. The German screenshots from the
QA run (`*_de_light_*`, `*_de_dark_*`) show it.

Fix: either translate the 377 keys, or delete the empty `de`, `es`, `fr` and `it` entries from
`Localizable.xcstrings` so the app falls back to English until translations exist. Do not ship a
localised App Store listing before this is closed.

### The app has no icon

`Corbie/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` declares one universal 1024x1024
slot and contains no image file, so the build has no icon and App Store Connect rejects the upload.
Fix: export the two-raven mark from `docs/02_BRAND_BOOK.md` section 2 at 1024x1024 into that
`.appiconset`.

### The server base URL is never configured

`ServerConfiguration.infoPlistKey` is `CORBIE_SERVER_URL`
(`Packages/CorbieCore/Sources/CorbieCore/Services/APIClientConfiguration.swift:4`) and no Info.plist
in the project sets it. `grep -rn CORBIE_SERVER_URL --include='*.yml' --include='*.plist' .` finds
nothing but the declaration. Every client call therefore goes to
`https://corbie.supabase.co/functions/v1` (`ServerConfiguration.fallback`, `:36`), which is a
placeholder project ref.

Effect today: invites cannot be created or redeemed, links never parse, currency rates never refresh,
the entitlement can only come from the local StoreKit transaction, and analytics never lands. Each of
those degrades into a hint rather than a crash (see `docs/TEST_PLAN.md` section 2), so it is invisible
until someone tries to pair.

Fix: add `CORBIE_SERVER_URL` to the Corbie and CorbieShare Info.plist blocks in `project.yml` with the
real Supabase project ref, per build configuration. `SessionService` already refuses to call a
placeholder (`Corbie/Features/Pairing/SessionService.swift:26`); `APIClient` does not, and could get
the same guard so the failure names the cause instead of a network error.

## Minor

### The Us counters still show a dash when there is nothing to count

`UsHubView.counterColumn` renders `Text(value.map { $0.formatted() } ?? "-")` in the 56pt counter
font. On a new space with no together-since date and no upcoming date, both columns render a hyphen
at counter size. The QA pass dropped it to the secondary colour so it stops reading as a redaction
bar, but a 56pt dash is still a placeholder standing where a number belongs.

Reproduce: fresh install, skip the together-since date in onboarding, open the Us tab. Screenshot
`tab4_us` from the QA run.

Fix, for the founder to decide: drop the number entirely when there is nothing to count and let the
mono caption carry the state, which is what `us.counters.empty` already says.

### A list item exposes two buttons with the same VoiceOver label

`ListItemRow` builds a checkbox button labelled with the item title and a details button whose label
is the same title (`Corbie/Features/Plans/Lists/ListItemRow.swift:24` and `:38`). VoiceOver announces
"Milk, button" twice in a row and only the value ("ticked" / "not ticked") tells them apart; a UI test
matching on the label has to disambiguate by value. Fix: give the details button its own label, for
example the item title plus its note, or fold the two into one element with a custom action.

### The primary button is not the accent colour

`CorbiePillButtonStyle(variant: .filled)` fills with `CorbieColorPalette.text` and writes in
`bg`, so every primary call to action is a black pill on light and a white pill on dark
(`Packages/CorbieCore/Sources/CorbieCore/Design/Components/PillButtonStyle.swift:35`). The brand book
names `ice` `#8FC5E8` as the single accent, "buttons, progress, selections, active tab", and chips,
the progress bar and the active tab do use it. Screenshot `votes_answered` shows the black "Change
your answer" pill. This is a deliberate-looking design system choice from module 01, so it needs the
founder to decide rather than a silent change.

### StoreKit prices can never appear in an automated run

`Corbie.xcscheme` attaches `Products.storekit` to the LaunchAction only, so `xcodebuild test` runs
without a StoreKit configuration and the paywall renders `paywall.state.unavailable` ("The App Store
did not answer") instead of prices (screenshot `readonly_paywall`). The paywall copy is covered by
`CorbieTests/PaywallCopyTests.swift`, but no automated run can prove the layout with real prices in
it. Fix: add the same `storeKitConfiguration: Products.storekit` under `schemes.Corbie.test` in
`project.yml` and regenerate.

### The rating prompt from the spec does not exist

Spec section 12 asks for `SKStoreReviewController` after the third joint action and not before day
five. `requestReview` and `SKStoreReviewController` appear nowhere in the app.

### Notifications are asked for once and never re-offered in the app

If the first request is denied, the only route back is Settings, Notifications, "Open iOS Settings".
That is a real route and there is no dead end, but nothing in the feature screens hints that a
reminder was not scheduled: `TaskDueNotifications` and the capsule editor swallow the refusal
silently. Worth a one-line hint next to the due date toggle once someone has denied.

## Found by the first full UI run on 2026-09-06 (before the amendment rework)

- minor: `SmokeTabsUITests.testCapsuleCreate` does not find the new capsule in the list right after saving; unclear whether the list refreshes late or the row label differs from the title. Reproduce during the Today and Us rework.
- test debt: eight QA UI tests fail on "the Us hub has no settings entry" because they look for the settings row by a label that the localization pass changed; with the amendment the hub opens from the pill, so these tests are rewritten in the QA pass after the rework rather than patched now.
- test debt: `QAPermissionsUITests.testThePhotoPickerIsReachableWithPhotosDenied` taps an ambiguous "Cancel" (two matches on screen).
