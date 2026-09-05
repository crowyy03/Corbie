# Module 04 — Tasks

Read spec §6.3, §7 (TaskItem), brand microcopy.

## Goal
Full Tasks tab.

## Do
1. `TasksView`: chips All/Mine/{Partner}/Free with counts; sections "In progress" and "Free"; empty state per brand.
2. Row: member dot (gray when free), title, mono subtitle "you took yesterday · due Aug 20" / "{Partner} set · due Aug 24" (relative dates via `RelativeDateTimeFormatter`), "Take" button on free tasks. Swipe right = done, swipe left = take/hand back. Context menu: edit, hand back, delete (author only).
3. `TaskEditorView`: What to do; Who segmented Nobody/Me/Partner with helper text; Due toggle → date; Repeat picker (none/daily/weekly/monthly/weekdays); Note; info block.
4. Recurrence: on marking done, if recurrence != none create next occurrence (`RecurrenceEngine` in CorbieCore, unit-tested; handles month-end).
5. Hand back: sets assignee nil, keeps history fields.
6. `TasksViewModel` observes repository via `NSFetchedResultsController` wrapper publishing DTOs.
7. Analytics: task_created(assignee), task_taken, task_done, task_handed_back.
8. Premium gate: creating tasks is premium after trial (read-only mode shows paywall on "+"); viewing always allowed. Use `PremiumGate.require(.create)` helper (Module 11 provides; stub now).

## Verify
Create/assign/take/hand back/done/recurring on device; both partners see updates; unit tests for recurrence.
