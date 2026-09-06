# Module 05 — Calendar, dates, iOS calendar import

Read `docs/01a_SPEC_AMENDMENT_01.md` first (it adds the free-time entry point), then spec §6.4, §6.11 (Our dates), architecture §11–12.

## Do
1. `CalendarView`: month grid using `Calendar.current` (firstWeekday from locale), navigation arrows, today filled `ice`, up to two member-colored dots per day, multi-day events drawn as `ice` bars across the row (compute spans per week row). "Upcoming" list below with "Add".
2. `EventEditorView`: title, all-day toggle, start/end, kind picker (Event/Birthday/Anniversary/Trip), person picker (for Birthday, from People — Module 09; stub list now), location search (`MKLocalSearchCompleter`) optional, note, reminders multi-select (day before, 3 days, 2 weeks).
3. `EventDetailView`: fields + flat comment thread (max 200 chars each, member dot, time), "Add to iPhone Calendar" (EventKit `EKEventEditViewController`).
4. Auto dates: from Space (together since → yearly anniversary; wedding date) and People birthdays → virtual events (not stored; computed provider `AutoDatesProvider`).
5. Import from iPhone Calendar (Settings): request access, list calendars, select, copy events in next 12 months as `Event` (dedupe by title+start). One-shot.
6. Local notifications for reminders (`NotificationScheduler` in CorbieCore; respects prefs).
7. Calendar is **always free** — no premium gate on create/edit here.
8. Add a toolbar button `When we're both free` (clock icon) that presents `FreeTimeView`. Module 17 implements it; for now wire a placeholder sheet so the entry point exists and is localized.

## Verify
Grid renders correctly for locales en_US (Sunday) and de_DE (Monday); multi-day spans; import works; reminders fire.
