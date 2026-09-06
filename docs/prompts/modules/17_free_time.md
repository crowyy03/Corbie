# Module 17 — "When we're both free"

Read `docs/01a_SPEC_AMENDMENT_01.md` (feature A). Run after Module 05. This module touches privacy — follow the rules exactly.

## Goal
Show slots when both partners are free, computed from device calendars, without ever revealing what either person is doing.

## Do
1. **New entity `BusyInterval`**: id, spaceId, memberId, startAt, endAt, source (`device|corbie`), updatedAt. **No title, no location, no attendees, ever.** Add to the Core Data model and CloudKit schema.
2. **`BusyPublisher`** (CorbieCore):
   - Reads the device's EventKit calendars (`EKEventStore.requestFullAccessToEvents`) for the next 14 days.
   - Converts events to intervals: skip events marked as `.free` availability, skip declined invitations, treat all-day events as full-day busy.
   - Merges overlapping intervals per member.
   - Adds intervals from Corbie's own `Event` records (source `corbie`) — these are published regardless of the toggle, since both partners already see them.
   - Writes device-sourced intervals **only if** `Member.sharesBusyTimes == true`.
   - Runs on foreground, throttled to once per hour, and on `EKEventStoreChangedNotification` (debounced 30s). Deletes intervals older than now and beyond the 14-day horizon.
3. **`FreeSlotEngine`** (pure, unit-tested): given both members' intervals, a date range, working hours bounds (default 08:00–23:00 local), and a minimum duration, return free slots. Handles: time zones (partners may differ — compute in each viewer's local zone and label the partner's zone when they differ by ≥2h), day boundaries, all-day blocks, and "no data for partner" (return a clear state, not an empty list).
4. **`FreeTimeView`** — modal from a Calendar toolbar button (`clock.badge.checkmark` style icon):
   - Range segmented: `Next 7 days` / `Next 14 days`.
   - Filter chips: `Evenings` (after 18:00), `Weekends`, `2+ hours`.
   - Result rows: `Thu, Sep 10 · after 7:00 PM`, `Sat, Sep 12 · all day`, `Sun, Sep 13 · 10:00 AM – 2:00 PM`. Duration on the trailing side.
   - Tap a slot → `EventEditorView` prefilled with that start/end.
   - States: partner hasn't enabled sharing → `{Partner} hasn't shared their busy times yet` + a `Nudge` button sending a local-notification-triggering flag through CloudKit (reuse Module 12 mechanism). You haven't enabled → inline explainer + toggle. No free slots → `You two are booked solid. Try a longer range.`
5. **Privacy UI** (mandatory copy): first entry shows a sheet — `Corbie only shares when you're busy — never what you're doing. Titles, locations and guests stay on your phone.` with `Share my busy times` / `Not now`. Same toggle in Settings; turning it off **deletes all of that member's `device`-sourced intervals** from the space immediately.
6. **Optional widget** (only if it fits the timeline): `FreeSlots` medium — next two shared free windows.
7. **Premium gate**: the screen is premium after trial.
8. **Analytics**: `freetime_opened`, `freetime_sharing_enabled/disabled`, `freetime_slot_tapped`, `freetime_empty(reason)`.

## Verify
- Two devices, two Apple IDs, overlapping and non-overlapping calendars: slots are correct.
- No event title, location or attendee ever reaches CloudKit — inspect records in CloudKit Dashboard and confirm.
- Toggling sharing off removes the records within seconds.
- Different time zones: labels are correct for each viewer.
- Calendar permission denied: screen explains and offers Settings deep link, no dead end.
- Unit tests for `FreeSlotEngine`: adjacent intervals, all-day, DST boundary, empty partner data.
