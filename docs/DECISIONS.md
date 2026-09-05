# Decisions

Running log of implementation decisions not covered by the spec. Newest at the bottom.

## 2026-09-05

- Xcode project is generated from `project.yml` via XcodeGen so that project structure lives in a reviewable text file. Regenerate with `xcodegen generate` after editing `project.yml`.
- `CorbieCore` declares `.macOS(.v14)` alongside `.iOS(.v17)` so that the package builds and tests with `swift build` / `swift test` on a Mac without Xcode. UIKit-only code is guarded with `#if canImport(UIKit)`.
- The spec's `Task` entity is named `TaskItem`, `List` is `ChecklistList`, to avoid clashing with Swift standard library types.
- Tests use Swift Testing. Command Line Tools include neither XCTest nor Testing, so `scripts/test_core.sh` adds `swift-testing` 6.1.3 as an opt-in dependency through `CORBIE_EXTERNAL_TESTING=1` (6.2+ needs `_TestingInterop`, which the CLT toolchain lacks). Xcode ignores the flag and uses its bundled Testing.
- Core Data model is built programmatically (`NSManagedObjectModel` in code) instead of `.xcdatamodeld`, because `momc` is not available outside Xcode and a code model is diffable and unit-testable against the CloudKit rules (optional/default attributes, no unique constraints, no ordered relationships, inverses everywhere).
- Module 00: the Xcode project is generated into the repository root and committed, so the founder can open it without XcodeGen installed. `project.yml` stays the source of truth; `Configs/` holds the per-target entitlements and the Info.plist files XcodeGen writes.
- Module 00: XcodeGen 2.46 cannot put a Swift package test target into a scheme ("Spec validation error: Scheme "Corbie" has invalid test target "CorbieCoreTests""). The Corbie scheme therefore tests `CorbieTests` and `CorbieUITests`; `CorbieCoreTests` runs through `scripts/test_core.sh`.
- Module 00: one string catalog, `Corbie/Resources/Localizable.xcstrings`, is compiled into the app, the widget and the share extension, so a key resolves the same way in all three bundles.
- Module 00: the tab skeleton uses stock SwiftUI styling. It moves to `CorbieCore/Design` tokens and components once Module 01 lands.
- Module 00: `NSUserNotificationsUsageDescription` is in the app Info.plist because the module prompt asks for it; iOS does not read that key, the notification permission prompt has no usage string.

## 2026-09-05 (review pass)

- Every child object is assigned to the persistent store of its parent (`context.assign(_:toStoreOf:)`) and a new `Space` is assigned to the private store explicitly. Core Data on the current toolchain already places a related insert in its parent's store and an unrelated one in the first store, so this is not a behaviour change; it makes the placement intentional instead of implicit, and `StoreAffinityTests` pins it with a real two-store on-disk stack.
- `CoreDataStack.store(for:)` falls back to "the only store" only when that store is in memory. On disk, a scope whose file is not loaded returns nil, so accepting a share can no longer land in the private store when the shared one failed to open.
- `CoreDataStack(storesIn:)` opens the private and shared stores in a given directory without CloudKit. It is how the two-store tests run on macOS.
- Leaving and deleting a space are now separate paths guarded by the store the `Space` lives in. A participant leaves by deleting the `CKShare` from the shared database and purging the mirrored zone (`purgeObjectsAndRecordsInZone`), never by deleting the mirrored objects, which would export deletions of the owner's records. The owner deletes the share from the private database and then the local objects. A missing share is an error, not a silent local wipe.
- `PersistentHistoryObserver` merges `NSPersistentStoreRemoteChange` transactions written by the other processes into the view context, keeps its token in the App Group defaults under `history.token.<author>`, purges history older than seven days and posts `WidgetReloadRequest` after a merge.
- `Member` stores `appleUserHash`, the SHA-256 of the Sign in with Apple identifier, per spec section 7. The raw identifier stays in the Keychain and never reaches Core Data or the partner's device. The repository still takes the raw id and hashes it at the boundary.
- `Vote` answers are one `VoteResponse` record per member instead of one JSON blob, so each device writes only its own row and the property merge policy cannot drop a partner's answer. `VoteDTO.responses` is unchanged.
- Plan money has one base: `savedAmount` is the "Saved so far" figure the user types (spec 6.6), `progress` and `leftAmount` are both measured against it, and expenses are reported separately as `spentAmount` and `overspentAmount`. Expenses do not move `savedAmount`.
- `revealedAt` is stamped only when everyone has answered or when someone reveals the vote by hand. `canSeeResults(as:)` additionally requires the viewer to have answered, so "Reveal only when both answered" turned off never shows one partner the other's choice for free (spec 6.9).
- The pinned Shopping list takes its title from the caller. Package code cannot resolve the app's string catalog, so a `String(localized:)` key persisted from `CorbieCore` would be stored and synced verbatim.
- An author-only list denies a tick when the member or the author is unknown, falling back to the list creator when the item records no author.
- The app is iPhone only: `TARGETED_DEVICE_FAMILY = 1` on the app, widget and share targets. The design is portrait-only and single column, and the Info.plist already declares portrait alone.
- `CKSharingSupported` is in the app Info.plist and `AppDelegate.application(_:userDidAcceptCloudKitShareWith:)` calls `CloudKitSharing.acceptShare(metadata:)`, so an invitation link actually joins the space.
- Each tab is a bare `NavigationStack` around its feature root; the feature view owns its title and toolbar and adds the pill with `.toolbar { UsPillToolbarItem() }`. The pill is the `CorbieCore` `UsPill` component, which already meets the 44pt tap target.

## 2026-09-05 (module 07)

- Big lists active and completed plans; archiving takes a plan out of the tab. There is no archive screen in v1, so archive is the way to put a finished plan away, and `corbie://plans/<id>` still opens it.
- Plan money is shown in the plan currency, not in the space display currency. `targetAmount` and `savedAmount` are stored in the plan currency, so showing them in another currency would mean converting numbers the user typed at a rate that changes under them. A new plan defaults to the space currency, which is what makes the two agree in practice; only an expense in another currency is converted, once, at add time, with the rate kept on the expense.
- The pinned Shopping list is created the first time the Plans tab loads and is not premium gated: it is the container the Shopping widget and its App Intent expect, not user content. It cannot be deleted from the list menu, only edited.
- Ticking an item, reordering, clearing done and adding an expense all go through `PremiumGate`, as create or edit. Reading stays open, so a read only pair still sees every plan, list, item and place.
- List and Map is one screen with two modes behind a toolbar button, not a second navigation destination. Reordering uses the system `EditButton` because a plain SwiftUI `List` only starts a drag in edit mode.
- `AnalyticsEvent` gained `listItemChecked` and `listMapOpened` (`list_item_checked`, `list_map_opened`). They are deliberately absent from `AnalyticsEvent.allowedNames`, the server allowlist and architecture section 13; the server drops unknown names one by one, so the events are recorded and discarded until all four places are updated together.
- Deleting a plan or a list is not in the module prompt but is the only way out of a mistyped one, so both sit behind a confirmation in the screen menu.
