# Module 07 — Plans (Big + Lists) with multi-currency and map

Read spec §6.6, architecture §10, §11.

## Do
1. `PlansView` with top segmented Big / Lists.
2. Big: cards with type icon, title, `ProgressBar` (overspend segment), "$2,400 of $5,000" (space-currency formatting), dates if set. `PlanEditorView`: title, type chips, target amount + currency, saved so far, dates optional, note. Info block copy from spec.
3. `PlanDetailView`: progress, expenses list (amount in original currency + "≈ plan currency", note, date, member dot), add expense sheet (amount, currency, note, date). Compute `savedAmount` = initial saved + sum(expenses) — decide: treat "saved so far" as contributions and expenses as spending; show "Saved", "Spent", "Left". Overspend when spent > target. Mark completed / archive.
4. `FXService`: `APIClient.fx(base:)` cached 24h in App Group UserDefaults; convert at add-time and store rate on the expense.
5. Lists: `ListEditorView` with title, subtitle, template chips (Places to go / Things to watch / What to cook / Cities / Shopping / Empty), toggle anyone-can-tick. Templates seed 0 items but set an icon and default subtitle hint.
6. `ListDetailView`: items with checkbox (records who checked), add item inline, swipe delete, reorder; toggle **List / Map** in toolbar. Item editor: text, note, "Add place" → `MKLocalSearch` sheet → store name/address/coords. Map mode: SwiftUI `Map` with annotations colored by author, tap → sheet with note + "Open in Maps".
7. Shopping: one pinned list per space (created lazily), items with "Clear done".
8. Premium gate on create/edit after trial.
9. Analytics: plan_created(type), expense_added, list_created(template), list_item_checked, list_map_opened.

## Verify
Multi-currency expense shows correct conversion and persists rate; overspend renders; map pins render with member colors; Shopping list pinned.
