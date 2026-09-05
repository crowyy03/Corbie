# Module 10 — Widgets (Home + Lock Screen)

Read spec §8, architecture §7, §18 (5–6).

## Do
1. `CorbieWidgets` target with a `WidgetBundle` containing 13 widgets from spec §8. Shared `WidgetDataProvider` in CorbieCore reading the App Group store (read-only context).
2. Timeline policy: entries now + next midnight; `.after(midnight)`. Reload on `WidgetReloadRequest` from app/extension/intents.
3. Interactive: `ToggleTaskDoneIntent(taskID)`, `TakeTaskIntent(taskID)`, `ToggleShoppingItemIntent(itemID)` in CorbieCore (AppIntents), performing writes on a background context and posting reload.
4. Configurable: `CountdownWidget` (AppIntentConfiguration selecting a date source: anniversary / wedding / partner birthday / custom event), `PlanProgressWidget` (select plan), `LockCircularWidget` (mode: days / plan ring / countdown).
5. Visual rules: dark surfaces from Design tokens, mono captions, member dots for ownership, gray for free tasks. Large `OurDay` composes days, next date, plan, 3 tasks.
6. Lock screen: circular ring/number, rectangular next task or date, inline countdown; `widgetAccentable()`; test rendered in monochrome.
7. Premium gate: widgets except `DaysTogether` and `Countdown` show a "Unlock in Corbie" placeholder with deep link when not premium.
8. Deep links from each widget to the relevant screen (`corbie://tasks`, `corbie://wishes`, `corbie://plans/{id}`, `corbie://capsules`).
9. Previews for every widget family.

## Verify
On device: add each widget; tap checkbox in Tasks widget → done in app within 1s; lock screen widgets render; timeline refreshes at midnight (simulate by changing date in Settings).
