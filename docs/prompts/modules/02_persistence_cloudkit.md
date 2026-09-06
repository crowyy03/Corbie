# Module 02 — Persistence: Core Data + CloudKit sharing

Read `docs/01a_SPEC_AMENDMENT_01.md` (data-model section) **first**, then `docs/03_TECH_ARCHITECTURE.md` §3, §15, §18 (items 1–5) and `docs/01_PROJECT_SPEC.md` §7. The amendment renames and removes entities — build the amended model, not the base one. This is the riskiest module; be careful.

## Goal
`CorbieCore/Persistence` + `CorbieCore/Model` with a CloudKit-synced, shareable Core Data stack usable from app, widgets and share extension.

## Do
1. `Corbie.xcdatamodeld` with entities from spec §7: Space, Member, `TaskItem` (named so to avoid clashing with Swift `Task`), `TaskFolder`, Event, EventComment, Wish, `Goal`, `GoalExpense`, `GoalStep`, `BusyInterval`, Capsule, Vote, Person, GiftIdea. **Do not create `ChecklistList` or `ListItem`** — lists are `TaskFolder` + `TaskItem.folderId`. Field lists for the new/changed entities are in the amendment. Rules: every attribute optional or defaulted; `id: UUID` indexed; no unique constraints; no ordered relationships; bidirectional relationships with delete rules (Space→children cascade; child→Space nullify). Enums stored as `String`. `Vote.responses` and `Member.notificationPrefs` stored as `Data` (JSON) with computed wrappers. `Wish.localImage` as external binary.
2. `CoreDataStack`: `NSPersistentCloudKitContainer` with two `NSPersistentStoreDescription`s in the App Group directory: `private.sqlite` (`.private` scope) and `shared.sqlite` (`.shared` scope), container id `iCloud.app.corbie`, history tracking + remote change notifications ON for both. `viewContext.automaticallyMergesChangesFromParent = true`, merge policy `NSMergeByPropertyObjectTrumpMergePolicy`.
3. `#if DEBUG` one-shot `initializeCloudKitSchema(options: [])` behind an env flag `CORBIE_INIT_SCHEMA=1`.
4. `CloudKitSharing`: 
   - `func share(space:) async throws -> CKShare` using `container.share([space], to: nil)`; set `share[CKShare.SystemFieldKey.title] = "Corbie"`, `publicPermission = .none`; persist share via `container.persistUpdatedShare`.
   - `func acceptShare(metadata:) async throws` via `container.acceptShareInvitations`.
   - `func currentSpace() -> Space?`: query both stores; prefer the one with 2 members; else the one owned by current user.
   - `func leave(space:)` — remove participant / delete from shared store; `func deleteSpace(space:)` for owner.
   - Handle `UIApplicationDelegate userDidAcceptCloudKitShareWith` and SwiftUI scene phase equivalent.
5. `PersistenceController.shared` + `.preview` (in-memory) for tests/previews.
6. Repositories in `CorbieCore/Repositories`: protocol per entity + Core Data implementation. Writes on background context; reads return DTO structs (`TaskDTO`, …). Each repository posts `WidgetReloadRequest` after save (a lightweight notification consumed by app/extension to call `WidgetCenter.reloadAllTimelines()`).
7. `MemberIdentity`: resolves current `Member` from Sign in with Apple user id stored in Keychain (created in Module 03).
8. Unit tests with in-memory store: create space, add task, fetch by filters, recurrence helper, cascade delete.

## Verify
- Build all targets.
- Tests pass.
- Manual: run on device with iCloud account; create Space; confirm records appear in CloudKit Dashboard dev environment.

## Report
Explain how the two-store setup routes Space records for owner vs partner and what must be tested on two Apple IDs later (Module 03).
