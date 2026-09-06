# Module 07 — Goals (renamed from Plans) with prep checklist

Read `docs/01a_SPEC_AMENDMENT_01.md` (change 3) **first**, then spec §6.6, architecture §10. Lists are **not** part of this module anymore — they live in Tasks (Module 04).

## Goal
A money-and-preparation section: savings goals with expenses and an internal prep checklist.

## Do
1. **Rename** across the codebase: `Plan` → `Goal`, `PlanExpense` → `GoalExpense`, `PlansView` → `GoalsView`, `plans` deep link → `corbie://goals`. Update widget `PlanProgress` → `GoalProgress`. Provide a Core Data migration mapping model.
2. **New entity `GoalStep`**: id, goalId, title, note?, isDone, doneByMemberId?, doneAt?, assigneeMemberId?, dueAt?, sortIndex. Goal→steps cascade.
3. **GoalsView**: cards with type icon, title, `ProgressBar` (overspend segment in `warn`), `$2,400 of $5,000`, dates if set, and a small `3/7 steps` badge when the goal has prep steps. Sections Active / Completed. Empty state per brand: `What are you two up to? A trip, a kitchen, a wedding, a car. Set the amount — see what's left.` mono sub: `one pot, no "who owes whom"`.
4. **GoalEditorView**: title, type chips (Trip / Purchase / Renovation / Event / Other), target amount + currency, saved so far, dates optional, note. Info block: `Shared goal: your partner sees it right away and can edit expenses — including yours`.
5. **GoalDetailView** — three sections:
   - **Progress**: Saved / Spent / Left, progress bar, overspend badge `+$340` in `warn`.
   - **Expenses**: rows (amount in original currency + `≈ goal currency`, note, date, member dot). Add sheet: amount, currency menu, note, date. Store `fxRate` and `amountInGoalCurrency` at add time via `FXService`.
   - **Preparation**: checklist of `GoalStep`. Inline add field. Row: checkbox, title, optional assignee dot and due date, note disclosure. Swipe delete, drag to reorder.
6. **Steps with a due date surface elsewhere**: a `GoalStep` with `dueAt != nil` is mirrored into Tasks and Today as a read-through item labeled `from goal: {Goal title}`. Implement with a `UnifiedTaskProvider` in CorbieCore that merges `TaskItem` and dated `GoalStep` into one sorted list; checking it from Tasks/Today writes back to the step. Steps without a due date never appear outside the goal.
7. **Completion**: "Mark completed" moves the goal to Completed and counts it in stats; archived goals are read-only.
8. **Premium gate** on create/edit after trial.
9. **Analytics**: `goal_created(type)`, `expense_added`, `goal_step_created(hasDue)`, `goal_step_done`, `goal_completed`.

## Verify
- Multi-currency expense stores and displays the historic rate.
- Overspend renders past 100% in `warn`.
- A step with a due date appears in Tasks/Today with the goal label and toggling it there marks it done in the goal.
- A step without a due date never leaks into Tasks.
- Migration from `Plan` preserves existing data.
