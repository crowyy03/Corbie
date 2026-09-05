# Module 09 — People + gift ideas + date radar

Read spec §6.10, §9 (notification 5).

## Do
1. `PeopleView` (from Us hub): list of Person rows (name, relation, birthday, owner dot). Add/edit: name, relation (free text with suggestions: Mom, Dad, Sister, Brother, Friend, Colleague), birthday month/day, owner (me/partner), note.
2. Birthdays feed `AutoDatesProvider` (Module 05) as Birthday events; reminders per prefs.
3. `PersonDetailView`: fields + "Gift ideas" list: title, link (uses `LinkParser`), price+currency, note, done toggle.
4. Date radar: `RadarService` computes, for each upcoming date within 14 days (partner birthday, anniversary, People birthdays), whether a gift is picked (any wish of the partner marked fulfilled after last date? — simplify: any GiftIdea with `isDone` for person, or for partner any wish fulfilled in the last 30 days). Schedules local notification at T-14 days 10:00 local: "14 days to Anna's birthday · 3 ideas saved / no gift picked".
5. Radar surfaces in Calendar "Upcoming" as a subtle line under the date and in the `UpcomingDates` widget.
6. Premium gate on People (view allowed in read-only).

## Verify
Add person with birthday in 10 days → appears in calendar; notification scheduled; gift idea done toggles radar text.
