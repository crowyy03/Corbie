# Module 04 — Tasks (with folders, replaces old Lists)

Read `docs/01a_SPEC_AMENDMENT_01.md` (changes 1, 2) **first**, then spec §6.3 and §7. The amendment overrides the base spec: `ChecklistList` and `ListItem` no longer exist; a task may belong to a `TaskFolder`.

## Goal
One Tasks tab that covers both "things to do" and "shared lists".

## Do
1. **Model** (extend Module 02 output):
   - `TaskItem` gains `folderId: UUID?`, `placeName/address/lat/lon` (all optional), `sortIndex: Int`, `sourceGoalId: UUID?`.
   - New entity `TaskFolder`: id, spaceId, title, subtitle?, template (`shopping|watch|places|cities|empty`), anyoneCanCheck (default true), isPinnedShopping, sortIndex, createdByMemberId. Relationship Space→folders cascade, folder→tasks nullify (deleting a folder keeps its tasks as plain tasks — confirm this in a confirmation dialog).
   - Migration: if a previous build shipped `ChecklistList`/`ListItem`, map them; otherwise just add.
2. **TasksView header**: two chip rows.
   - Row 1 (owner): `All · N`, `Mine · N`, `{PartnerName} · N`, `Free · N`.
   - Row 2 (folder): `All`, then folders in `sortIndex` order, then a `+` chip that opens the folder editor. Shopping folder always first if it exists.
   - Rows scroll horizontally, selected chip uses `ice` tint.
3. **List body**: sections "In progress" and "Free" when folder filter is `All`; inside a folder show a flat checklist (unchecked on top, checked below, dimmed) with a "Clear done" toolbar action for the Shopping folder.
4. **Row**: member dot (gray = free), title, mono subtitle (`you took yesterday · due Aug 20` / `{Partner} set · due Aug 24` / `from goal: Japan` when `sourceGoalId != nil`), place chip if a place is attached, `Take` button for free tasks. Swipe right = done, swipe left = take/hand back. Context menu: edit, hand back, add place, move to folder, delete (author only).
5. **TaskEditorView**: What to do · Folder picker (None + folders + "New folder…") · Who segmented `Nobody / Me / Partner` with helper text `"Nobody" — a free task, whoever gets there first` · Due toggle → date · Repeat (none/daily/weekly/monthly/weekdays) · Place (optional, `MKLocalSearch` sheet → name/address/coords) · Note. Info block: `Your partner sees it right away and can hand it back to free`.
6. **FolderEditorView**: title, subtitle (`Lisbon, this fall`), template chips (Shopping / Things to watch / Places to go / Cities / Empty), toggle `Anyone can tick / only the author`. Template sets icon + placeholder copy only, seeds no items.
7. **Map mode**: when the selected folder has ≥1 task with coords, show a `List / Map` toolbar toggle. Map uses SwiftUI `Map` with `Annotation` colored by the member who added; tap → sheet with note and "Open in Maps".
8. **Shopping**: created lazily on first use; `isPinnedShopping = true`; cannot be deleted, only emptied.
9. **Recurrence**: unchanged — `RecurrenceEngine` in CorbieCore, unit-tested, handles month-end.
10. **Premium gate**: creating/editing tasks and folders is premium after trial; viewing always allowed.
11. **Analytics**: `task_created(hasFolder, assignee)`, `task_taken`, `task_done`, `task_handed_back`, `folder_created(template)`, `folder_map_opened`.

## Verify
- Create a plain task and a task inside Shopping; both appear under the right chips.
- Free task can be taken and handed back by either partner.
- Folder with places shows the Map toggle; pins colored per author.
- Deleting a folder keeps its tasks (dialog confirms).
- Unit tests: recurrence, folder filtering, "clear done".
