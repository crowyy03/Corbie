# Module 19 — Question of the Day + Open savings (no-target goal)

Read `docs/01a_SPEC_AMENDMENT_01.md` and spec §6.6, §6.9, §8. Two independent features in one module; build Part A first.

---

# PART A — Question of the Day

## Goal
One question per day for the couple. Both answer blind; answers unlock only when both have written. History is kept forever and becomes one of the app's long-term assets.

## Data
1. **Bundled content**: `Questions.json` in `CorbieCore/Resources` — 1000 questions produced by the content brief (`docs/19b_QUESTIONS_CONTENT_BRIEF.md`). Schema per item:
   ```json
   { "id": "q0431", "theme": "memories", "stage": "any", "tone": "light", "text": { "en": "...", "es": "...", "fr": "...", "de": "...", "it": "..." } }
   ```
   Load lazily, decode once, cache in memory. Do **not** put these in the String Catalog — 5000 strings would bloat it.
2. **New entity `DailyQuestion`**: `id, spaceId, questionId (String), dayKey (String "2026-09-06"), createdAt`. One record per space per day, created lazily by whoever opens the app first.
3. **New entity `QuestionAnswer`**: `id, dailyQuestionId, memberId, text (max 500 chars), createdAt, editedAt?`.
4. **`Member` gains** `lastQuestionSeenDayKey: String?` for the badge.

## Selection algorithm
- `dayKey` is computed from the **space's anchor timezone** (the creator's timezone, stored on `Space.anchorTimeZone` — add it), so both partners see the same question on the same calendar day even across timezones.
- Deterministic shuffle: seed a `SeededGenerator` with `Space.id.uuidString` hashed; shuffle the full question id list once and store the resulting order as `Space.questionOrder` (compact string of indices or a seed + index pointer — prefer storing just `questionSeed` + `questionIndex` and recomputing).
- Advance the index by 1 per day. **Never repeat until all 1000 are used** (≈2.7 years).
- Filter by `stage`: questions tagged `6m+` or `2y+` are skipped if `Space.togetherSince` is unset or shorter. Skipped ids are simply passed over, not consumed.
- If `Questions.json` is somehow unavailable, fall back gracefully — no crash, hide the block.

## Flow and UI
1. **Today block** `Question of the day` (Module 16 feed, placed right after `Today`):
   - Question text in `screenTitle`-lite (24pt Bold, max 3 lines).
   - Status row with two member columns: `{Name} answered` (bold, member color) / `{Name} is still writing` (dim). Mirrors the competitor's pattern — keep our copy dry, no emoji.
   - CTA: `Answer` if you haven't; `See answers` when both have.
2. **`QuestionView`** (full screen from the block):
   - Question, a multiline text editor (500 char limit with counter appearing after 400), `Save`.
   - After saving and while the partner hasn't answered: your answer shown, partner's slot shows `Hidden until {Name} answers` with a `Nudge` button (reuses Module 12's nudge mechanism, max once per day).
   - When both answered: both answers revealed side by side with member dots and timestamps. Editing your own answer stays possible for 24h; editing after reveal marks `edited`.
3. **History**: `Questions` entry in the Us hub → reverse-chronological list of past days with both answers; search by text; tap for the full pair. Unanswered past days show as skipped and are not backfillable.
4. **Notification** (new type №11, `Question of the day`, default ON): fires at 10:00 local **only if** the partner has already answered and you haven't, plus a single daily reminder at 20:00 if neither has. Never two notifications in one day.
5. **Badge**: the Us pill badge (Module 08) also lights up when today's question is unanswered by you.

## Widgets (add to Module 10 bundle)
- `QuestionSmall` — today's question truncated + two dots showing answered state.
- `QuestionMedium` — full question + status row + `Answer` deep link (`corbie://question`). Not interactive (typing is impossible in a widget) — tap opens the app.

## Rules
- **Premium** feature (visible in read-only, answering gated).
- **No intimate or sexual content ever** — the bank is written for a 4+ rating. If a question would need an age gate, it does not belong in the bank.
- Answers are ordinary space data in CloudKit; they never touch our server.
- Analytics: `question_shown`, `question_answered`, `question_revealed`, `question_nudge_sent`, `question_history_opened`.

## Verify
- Two devices, two timezones (e.g. Europe/Moscow and America/New_York): both see the same question on the same `dayKey`.
- Answer on A → B sees `A answered`, cannot see the text. B answers → both reveal within 5s on both devices.
- Kill and relaunch: same question, no reshuffle.
- Advance the device clock 30 days: 30 different questions, no repeats.
- `stage` filtering: a space with `togetherSince` 2 months ago never sees `2y+` questions.

---

# PART B — Open savings (a goal with no target)

## Goal
A shared pot with no finish line: money just accumulates. Lives inside Goals next to targeted goals.

## Do
1. **`Goal` gains** `isOpenEnded: Bool` (default false). When true: `targetAmount` is ignored and may be nil.
2. **GoalEditorView**: a `Goal type` segmented control at the top — `With a target / Open`. Choosing `Open` hides the target-amount field and shows mono helper copy: `no finish line — money just adds up`.
3. **Card in GoalsView** (open-ended variant): no progress bar. Large amount in counter typography, title above, mono sub-line `since {Month Year} · {N} contributions`. Visually distinct from targeted goals so the list doesn't read as broken.
4. **GoalDetailView** (open-ended variant): total at the top, `Add` button, contributions list (amount + original currency + `≈` space currency, note, date, member dot). No "Left", no "Spent", no overspend. Withdrawals are supported as negative contributions with a distinct style — label them `Taken out` in `warn` color.
5. **Multi-currency**: same `FXService` rules as targeted goals — store the rate at add time.
6. **Widget**: `GoalProgress` gets an open-ended layout — title + amount + `{N} contributions`, no ring, no percentage. Handle the small/accessoryCircular families by showing the amount only.
7. **Migration**: existing goals get `isOpenEnded = false`. No data loss.
8. Analytics: `goal_created(type, isOpenEnded)`, `contribution_added(isNegative)`.

## Verify
- Create an open goal, add three contributions in two currencies and one withdrawal — total is correct, no progress UI anywhere.
- Widget renders the open variant in every supported family without layout breakage.
- A targeted goal still behaves exactly as before (regression check).

---

## Report
List new entities and fields, files added, the notification you registered, and confirm the question-selection determinism test passed on two devices.
