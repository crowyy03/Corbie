# Module 20 — Chore split by preference ("Who minds it less")

Read `docs/01a_SPEC_AMENDMENT_01.md`, spec §6.3 (Tasks + recurrence), §6.9 (Vote mechanic). Run **after** Modules 04, 08, 16. Ships in **v1**.

## The idea in one line
Every other app splits chores **evenly**. Corbie splits them by **who minds them less** — both partners rate blind, and the app hands each chore to whoever hates it least while keeping the total load balanced.

## Where it lives
- **Entry point: Us hub** — a tile `Chore split` next to Capsules and Vote. It's a ritual done once every few months, not a daily section, so it belongs here and not in the tab bar.
- **Prompt in Today**: a one-time card `You two haven't split the chores yet` → opens the flow. Shown only when a partner is connected and the split has never been run. Dismissible; never shown again after dismissal or completion.
- **Tasks empty state**: a secondary action `Split the recurring chores`.
- **Output lands in Tasks** as recurring tasks with assignees — no new concept for the user, and the existing `RecurrenceEngine` does the work.

## Data
1. **Bundled `Chores.json`** in `CorbieCore/Resources` — the catalog (see below). Schema:
   ```json
   { "id": "c012", "group": "kitchen", "defaultFrequency": "daily", "loadPerWeek": 7,
     "text": { "en": "Wash the dishes", "es": "...", "fr": "...", "de": "...", "it": "..." } }
   ```
2. **`ChoreSet`**: `id, spaceId, status (building/rating/revealed/applied), createdAt, revealedAt?, appliedAt?`. One active set per space; previous sets kept for history.
3. **`ChoreItem`**: `id, choreSetId, catalogId? (nil for custom), title, frequency, loadPerWeek, isIncluded, addedByMemberId, sortIndex`.
4. **`ChoreRating`**: `id, choreItemId, memberId, verdict (`hate | neutral | fine | like`), createdAt`. **Blind** — never fetched for display until both members have rated every included item.
5. **`ChoreAssignment`**: `id, choreItemId, result (`memberA | memberB | rotate | anyone`), scoreA, scoreB, createdAt`.
6. **`TaskItem` gains** `rotatesBetweenMembers: Bool` (default false) and `choreItemId: UUID?`.

## Flow

### Step 1 — Build the list (fast, no typing)
`ChoreListBuilderView`. **Do not show a blank text field first** — that kills completion. Show the catalog as toggle chips grouped by area, with ~15 common ones pre-selected:

`Kitchen · Cleaning · Laundry · Shopping · Money & admin · Pets · Plants · Car · Outside · Keeping in touch`

Each chip shows the chore and its default frequency; long-press to change frequency. A `+ Add your own` field sits at the **bottom** of each group. Header copy: `Pick the ones that actually happen in your place.` Mono sub: `you can both edit this list`.

Either partner can build; the list is shared, so the second sees it and can add or remove before rating starts. Requires ≥8 included items to continue.

### Step 2 — Rate blind (fast, fun)
`ChoreRatingView` — a card deck, one chore per card, swipeable:
- **Swipe left** → `hate` — `I'd rather not`
- **Swipe right** → `fine` — `I don't mind`
- **Swipe up** → `like` — `I actually like it`
- **Tap the middle button** → `neutral`

Progress dots at the top, `3 of 24`. 24 cards should take under 90 seconds. Undo last card. Nothing is revealed at any point during rating.

After you finish: `Done. Waiting for {Partner}.` with a nudge button (reuse Module 12 nudge, once per day). Partner gets a notification (type №12, `Chore split ready to rate`).

### Step 3 — The algorithm
`ChoreSplitEngine` (pure, in `CorbieCore`, **fully unit-tested**):

```
weight(verdict): like = +2, fine = +1, neutral = 0, hate = -2

For each item: scoreA, scoreB from each member's verdict.
Balance metric = sum of loadPerWeek assigned to each member.

1. Items where both rated `hate`      → result = rotate
2. Items where both rated `like`/`fine` and scores tie → hold for balancing
3. All others: sort by |scoreA - scoreB| descending (biggest disagreements are
   the cheapest wins) and assign to the higher scorer, provided that assignment
   does not push their load above (totalLoad/2 + maxSingleItemLoad).
4. Balance pass: assign held/blocked items to whichever side has less load.
5. If |loadA - loadB| still exceeds 15% of total, move the smallest item whose
   score difference is smallest, until within 15% or no move improves it.
6. Items nobody included in the list are ignored entirely.
```

Never expose the raw scores or the balance numbers as a "who does more" comparison. The engine's output is an assignment, not a verdict on a person.

### Step 4 — Reveal
`ChoreRevealView`. Lead with the wins, not the table:

- Headline: `You two agree more than you thought.`
- **Trade cards** — up to 4, the biggest disagreements: `You'd rather not do the dishes. {Partner} doesn't mind them.` → `Theirs now.` These are the shareable moment; make them look good.
- Then three lists: `Yours` · `{Partner}'s` · `Rotating` (both would rather not — alternates each time) · `Whoever's around` (free tasks, if any).
- Footer, understated: `Balanced by how often each one comes up.`

**Forbidden in this screen:** any fairness score, any "you do X%", any comparison of how much each person currently does, any implication that one partner was doing less. The feature exists to end that argument, not to arm it.

### Step 5 — Apply
Button `Add these to Tasks`. Creates one recurring `TaskItem` per item:
- `assigneeMemberId` from the assignment (`nil` for `anyone`)
- `recurrence` from the chore's frequency
- `rotatesBetweenMembers = true` for `rotate` results
- `choreItemId` set, so the task shows a mono sub-line `from the chore split`

**`RecurrenceEngine` change**: when completing a task with `rotatesBetweenMembers == true`, the next occurrence is assigned to the *other* member. Add unit tests for this.

Idempotency: applying twice must not duplicate tasks — match on `choreItemId` and update instead.

### Step 6 — Re-run
In Us hub, if `appliedAt` is older than 6 months: `Things change. Want to re-split?` Re-running creates a new `ChoreSet`, keeps the old one in history, and on apply updates existing chore tasks rather than duplicating them. History screen shows past splits with dates.

## Catalog — build ~44 items in these groups
- **Kitchen (7):** wash dishes, load/unload dishwasher, cook dinner, wipe counters, take out the trash, clean the fridge, restock kitchen basics
- **Cleaning (7):** vacuum, mop floors, clean the bathroom, dust, change the sheets, tidy the living room, clean windows
- **Laundry (4):** run the wash, hang or dry, fold and put away, ironing
- **Shopping (3):** grocery run, household supplies, plan the week's meals
- **Money & admin (5):** pay the bills, track the budget, book appointments, deal with mail and packages, renew documents and insurance
- **Pets (4):** feed, walk, litter or cage, vet trips
- **Plants (1):** water the plants
- **Car (3):** fuel, wash, service and inspections
- **Outside (3):** trash to the curb, yard or balcony, snow or leaves
- **Keeping in touch (7):** remember birthdays, buy gifts, plan the weekend, keep up with each other's families, reply to invitations, book travel, keep the shared calendar current

That last group is the invisible work most couples never name out loud. Include it — it is the most emotionally loaded and the most valuable part of the exercise.

`loadPerWeek` values: daily 7 · few times a week 3 · weekly 1 · every two weeks 0.5 · monthly 0.25 · quarterly 0.1.

Ship all five languages in `Chores.json` (44 × 5 = 220 strings, same natural-translation rules as the questions brief).

## Rules
- **Premium** feature. Visible in read-only, cannot start a new split.
- Requires a connected partner to reveal. Solo users can build the list and rate; the reveal waits.
- Ratings are never readable by the partner before both are done — enforce this in the repository layer, not just the UI, so a CloudKit sync race can't leak them.
- Analytics: `chore_flow_started`, `chore_list_built(itemCount, customCount)`, `chore_rating_done`, `chore_revealed(tradeCount, rotateCount)`, `chore_applied(taskCount)`, `chore_resplit`.

## Verify
- Two devices: A builds, B edits the list, both rate — neither sees the other's ratings at any point (check CloudKit Dashboard mid-flow).
- Engine unit tests: both hate → rotate; opposite preferences → correct trade; all identical ratings → balanced by load; load imbalance never exceeds 15%; a single daily chore never outweighs the balance rule.
- Rotation: complete a rotating task twice — assignee alternates.
- Apply twice → no duplicate tasks.
- Reveal screen contains no percentage, score, or comparison of either person.
