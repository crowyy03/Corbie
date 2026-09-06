# Module 18 — Sunday weekly recap

Read `docs/01a_SPEC_AMENDMENT_01.md` (feature B). Run after Modules 04, 05, 07, 16.

## Goal
A weekly return hook: a notification on Sunday evening and a card in Today.

## Do
1. **`RecapBuilder`** (CorbieCore, pure + unit-tested): given a space and a week range (Mon 00:00 – Sun 23:59 local), compute:
   - tasks completed per member (two numbers)
   - goals moved: title + delta + new percentage, up to 2
   - next week: dates and events, up to 3
   - wishes added per member
   - days together at week end, and whether a round milestone (100/365/500/1000) falls in the coming week
   No storage — computed on demand from existing records.
2. **`RecapCard`** view for the Today feed: header `Your week`, two member columns with completed counts, goal delta line, `Coming up` list, footer `1 250 days together`. Uses counter typography for the numbers, no emoji, no exclamation marks.
   Visible from Sunday 19:00 local until Monday 09:00 local, or until `Member.lastRecapSeenAt` is set by tapping it.
3. **Scheduling**: a repeating local notification, `DateComponents(weekday: 1, hour: 19)` in the user's calendar (weekday index must come from `Calendar.current`, not hardcoded — Sunday differs by locale). Title `Your week` / body `{A} closed 12, {B} closed 7. Three dates coming up.` Body is generated at schedule time from the previous week's data; reschedule every Sunday when the app next opens, and use a content extension-free approach (plain local notification).
   If the space has no partner yet or there was zero activity, **skip the notification** (but still show the card if there is anything at all).
4. **Settings**: notification toggle №10 `Weekly recap`, on by default.
5. **Free feature** — never gated, including in read-only mode. It is a retention mechanism.
6. **Analytics**: `recap_shown`, `recap_notification_sent`, `recap_opened`.
7. **v1.1 hook, do not build now**: leave a `// TODO: shareable recap card` marker where a share button would go.

## Verify
- Set the device clock to Sunday 19:00 → notification fires; card appears in Today.
- Zero-activity week → no notification.
- Locale where the week starts on Monday vs Sunday → correct week range and correct weekday index.
- Numbers match what's actually in the data (write a test with a seeded week).
