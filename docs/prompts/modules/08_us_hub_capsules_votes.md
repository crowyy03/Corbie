# Module 08 — Us hub, counters, Capsules, Votes

Read `docs/01a_SPEC_AMENDMENT_01.md` (changes 1, 5) first, then spec §6.7–§6.9. **Us is not a tab** — it opens modally from the pill in the trailing toolbar of every tab.

## Do
1. `UsHubView` (sheet from the Us pill, full-screen on iPhone): header "You two" + `UsPill` + close; tiles Capsules / Vote; counters card "N days together | M to {next date}" with counter typography; People tile with count; "Settings" row.
1a. **Badge on the pill**: an `ice` dot when any of these is true — a capsule is ready to open, a vote is unanswered, the partner added a wish since `Member.lastUsVisitAt`, or the gift radar is active. Opening the hub sets `lastUsVisitAt = now`. Expose this as `UsBadgeProvider` in CorbieCore so every tab toolbar can read it cheaply.
2. `NextImportantDate` provider: nearest of anniversary / wedding / partner birthday / custom pinned event; label like "to 2nd anniversary".
3. Capsules: list with three states styled per spec (waiting for you — highlighted; yours — lock; opened — envelope). `CapsuleEditorView`: To (partner), Title, Body (multiline, 5000 max), Opens on (date ≥ tomorrow). Author can edit until open date. Recipient sees only title + date. On open date both get local notification; `CapsuleOpenView` with a simple seal-break animation (no confetti), then "read by both" when both opened.
4. Votes: `VoteEditorView`: question, 2–4 options, mode single/multi, "reveal when both answered" toggle (default on). `VoteView`: answer; other's answer hidden until yours; reveal shows match/mismatch; multi mode shows only intersections. Templates on create: "Where to eat", "What to watch", "Weekend plan", "Custom".
5. Premium gate: Capsules and Votes are premium (after trial).
6. Analytics: capsule_created, capsule_opened, vote_created, vote_answered, vote_revealed.

## Verify
Capsule invisible to recipient before date; opens correctly across devices; vote reveal logic correct in single and multi modes.
