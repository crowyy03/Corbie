# Module 16 — Today tab

Read `docs/01a_SPEC_AMENDMENT_01.md` (changes 1, 4). Run **after** Modules 04, 05, 07, 08, 09.

## Goal
The start tab: everything that matters right now, assembled from existing data. No new entity.

## Do
1. **Tab bar becomes** `Today · Tasks · Calendar · Wishes · Goals`. Today is the default selected tab on launch. Remove the `Us` tab; keep the `Us` pill in the trailing toolbar of every tab (Module 08 handles the badge).
2. **`TodayFeedProvider`** in `CorbieCore` — a single provider that composes the feed. **The `OurDay` large widget must use this same provider** so screen and widget never disagree.
3. **Header**: today's date in `sectionCaps`, `1 250 days together` in counter style, member dots.
4. **Blocks** — render only when non-empty, in this order:
   - `Today` — events starting today + tasks/goal-steps due today, merged and sorted by time (all-day first). Row shows member dot, title, time, and `from goal: X` when applicable. Tap → detail. Checkbox toggles done inline.
   - `Free tasks` — up to 3 unassigned tasks with a `Take` button; footer `+N more` → Tasks tab filtered to Free.
   - `Coming up` — next 2–3 dates from `AutoDatesProvider` + events. If a birthday/anniversary is ≤14 days away and no gift is picked, highlight the row in `ice` with sub-line `no gift picked · N ideas saved` → taps into People.
   - `Goal` — the active goal with the nearest deadline (or the most recently updated if none has a deadline): title, progress bar, `$2,400 of $5,000`.
   - `Waiting for you` — capsule ready to open, unanswered vote, wishes your partner added since `lastUsVisitAt`. Each is a tappable row.
   - `Week recap` — Module 18 injects a card here on Sunday evening through Monday morning.
5. **Empty state**: `Nothing on today` + three quick actions: Add a task · Add a date · Invite your partner (last one only when solo).
6. **Refresh**: on appear, on foreground, and on Core Data remote-change notification. Pull-to-refresh triggers a CloudKit fetch.
7. **Deep links**: `corbie://today` is the target for all push notifications that don't have a more specific destination.
8. **Premium**: Today is always visible, including read-only mode. Inline actions (check a task, take a free task) are gated; tapping them in read-only opens the paywall.
9. **Analytics**: `today_opened`, `today_block_tapped(block)`, `today_quick_action(kind)`.

## Verify
- With no data at all: empty state with the right quick actions, no blank space.
- With data: blocks appear in order, nothing empty is rendered.
- `OurDay` widget shows the same items as the top of Today.
- Read-only: screen fully visible, checkbox opens paywall.
