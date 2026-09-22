# Two-device sync checklist

A check of every kind of thing a person can create, in both directions, with the `sync` log open on
both phones. It sits next to `docs/TWO_DEVICE_TEST_SESSION.md`, which covers pairing, notifications,
widgets and leaving: run its pre-flight (section 1) and steps 1 to 4 first, so the two phones are
paired, then come here.

Written on 2026-09-22 from the code. Nothing here has run on a device yet, and the log lines are what
the code writes, not something seen in Console. Every screen that shows stored data updates on its
own while it is open, from the same feed for local saves and synced changes (`docs/DECISIONS.md`,
2026-09-22). If the log shows the import but the screen only changes after you leave and reopen it,
write it down as a refresh problem, not a sync problem.

Names used below:

- **Owner** is the phone that created the space. Its copy of the space lives in its private store,
  so its lines say `store=private`.
- **Partner** is the phone that joined. Its copy lives in its shared store, so its lines say
  `store=shared`.
- **Share zone** is `com.apple.coredata.cloudkit.share.<id>`, the zone of the space's share. Both
  phones must name the same one.
- **Us pill** is the pair of coloured dots at the top right of every tab. It opens the Us hub.

---

## 1. Reading the sync log

1. Connect the iPhone to the Mac by cable, unlock it and trust the Mac.
2. Open Console.app, pick the iPhone in the sidebar under Devices, press Start.
3. In the search field type `subsystem:app.corbie`, press Return, then type `category:sync` and press
   Return again, so both filters show as tokens. Save the search (Save button under the search field)
   to get it back for the second phone.
4. All sync lines are Default or Error messages, so nothing needs to be switched on under Action.
5. For two phones, open a second Console window (File, New Window) and pick the other phone there.

What the lines say:

| Line | Meaning |
| --- | --- |
| `setup ok store=private` | Mirroring for that store started. One per store at launch. |
| `zones store=private spaces=<zones> shares=<zones>` | Once per store per launch, after its setup: the zone of each space in the store and of each share the store knows. Read from the phone's own metadata, no network. `unknown` means a space has no CloudKit record yet. |
| `export ok store=private zone=<zone> Wish +1 ~0 -0` | An upload finished. One line per zone and entity: inserts, updates, deletes. |
| `import ok store=shared zone=<zone> Wish +1 ~0 -0` | A download finished and wrote these rows into the store. |
| `export ok store=private no model changes` | The event finished but carried nothing of ours (metadata only). Normal. |
| `export failed store=private domain=CKErrorDomain code=2` | The event failed. With `code=2` (partial failure) the next lines name each record. |
| `export failed store=private record=<name> zone=<zone> code=14` | One failed record, at most 20 per event. |
| `export failed store=private dropped 7 more record errors` | Records past the 20 shown. |
| `export history restarted store=private reason=expired` | The log's own bookmark was older than the kept history (after a week or more without a sync). Harmless. |
| `purge asked store=shared zone=<zone> reason=leave` then `purge ok ...` | This phone emptied a zone because the person left or deleted the account (section 5). |
| `question consolidation merged 1 rows over 1 days` | Both phones had made a question of the day row for the same day and this phone folded them. |

How to read a row of the checklist:

- The phone that makes the change writes an `export ok` line with its own store and the share zone,
  usually a few seconds after the save.
- The other phone writes an `import ok` line with its own store and the same share zone after the
  silent push arrives, usually within a minute. If nothing comes after two minutes, bring Corbie to
  the foreground on that phone once and wait again.
- A change that touches several kinds of rows gives several lines, one per entity, in any order.
- `zone=com.apple.coredata.cloudkit.zone` on the owner means the record went to the owner's own
  default zone, which the partner never sees. That is the failure this checklist is looking for:
  copy the line and both zones lines into the session sheet.
- `zone=unknown` on a delete is normal: the record is gone. On an insert it means the record had no
  CloudKit id when the export finished; write it down.

Common error codes (`domain=CKErrorDomain`): 2 partial failure (look at the record lines), 3 or 4 no
network, 7 rate limited, 9 not signed in to iCloud, 11 record not found, 12 invalid arguments (often a
record type missing from the schema, section 2), 14 the server has a newer copy (the container retries
this itself), 23 zone busy, 25 iCloud full, 26 zone not found, 28 zone deleted by the user. Errors in
`NSCocoaErrorDomain` with a code starting 1344 come from Core Data's mirroring itself: copy the line as
it is.

---

## 2. Is the schema there

A Debug build uses the Development environment. Check it before the session:

1. Open `https://icloud.developer.apple.com`, CloudKit Database, container `iCloud.app.corbie`,
   environment **Development**.
2. Schema, Record Types. There must be 25 types that start with `CD_`, one per entity in
   `CorbieModel.swift`: `CD_Space`, `CD_Member`, `CD_TaskItem`, `CD_Event`, `CD_EventComment`,
   `CD_Wish`, `CD_Plan`, `CD_PlanExpense`, `CD_PlanStep`, `CD_ChecklistList`, `CD_ListItem`,
   `CD_BusyInterval`, `CD_CapsuleItem`, `CD_CapsuleOpen`, `CD_Vote`, `CD_VoteResponse`, `CD_Person`,
   `CD_PersonDate`, `CD_DailyQuestion`, `CD_QuestionAnswer`, `CD_ChoreSet`, `CD_ChoreItem`,
   `CD_ChoreRating`, `CD_ChoreAssignment`, `CD_GiftIdea`.
3. Open `CD_Member` and check it has `CD_revealReadDayKeysData`, the newest field.
4. If a type or field is missing, run a Debug build once with `CORBIE_INIT_SCHEMA=1`
   (`docs/APPLE_MANUAL_STEPS.md` section 2) and check again. Until then an export of that entity fails,
   usually with `code=2` and record lines with `code=12`.
5. To see the records themselves: Records, "Act as iCloud Account" with the owner's Apple ID, database
   Private, zone = the share zone from the owner's `zones` line. For the partner, act as the partner's
   Apple ID, database Shared, same zone name. A query by record type may ask for a queryable index on
   `recordName`; add it in Development if it does.

The Dashboard was not opened while writing this. Menu names are from memory and may differ slightly.

---

## 3. Before the rows

1. Both phones run the same build and are paired.
2. Console streams the `sync` search for both phones.
3. Relaunch Corbie on both phones and write down the two `zones` lines. The owner's
   `zones store=private spaces=` and the partner's `zones store=shared spaces=` must name the same share
   zone. If they differ, or the owner's says `com.apple.coredata.cloudkit.zone`, stop: nothing below can
   pass.
4. Keep Corbie in the foreground on both phones for every row unless the row says otherwise.
5. For each row: make the change on one phone, wait for its `export ok` line, wait for the other
   phone's `import ok` line, then look at the screen named in the row. Tick the box only when both
   lines and the screen agree.

In the lines below, `<zone>` is the share zone from step 3.

---

## 4. Rows

### 4.1 Together-since and wedding date

**Create:** Us pill, "Shared settings", section "Our dates": switch on "Together since" and pick a past date, then switch on "Wedding" and pick a date. Each change saves at once.

**Look on the other phone:** Us hub counter "days together", the Today header, and in Calendar the "Together since" and "Wedding anniversary" entries. The partner's Shared settings show the same dates.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> Space +0 ~1 -0`. Partner: `import ok store=shared zone=<zone> Space +0 ~1 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> Space +0 ~1 -0`. Owner: `import ok store=private zone=<zone> Space +0 ~1 -0`.

Two quick changes can go up in one export and read `Space +0 ~2 -0`.

### 4.2 Member profile

**Create:** Us pill, "Shared settings", section "You": change "Name" and tap its "Save", pick another "Color", switch on "Birthday" and set a month and day. Colour and birthday save the moment they change.

**Look on the other phone:** Shared settings, "Partner" row (the new name), the Us pill dot colour, Calendar "(name)'s birthday" and the Us hub birthday counter.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> Member +0 ~1 -0`. Partner: `import ok store=shared zone=<zone> Member +0 ~1 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> Member +0 ~1 -0`. Owner: `import ok store=private zone=<zone> Member +0 ~1 -0`.

Each of the three saves is its own write, so expect one to three `Member` update lines, or one line with `~2` or `~3`.

### 4.3 Task

**Create:** Tasks tab, "+", "New task": "What to do", "Who" set to the other person, "Save".

**Look on the other phone:** Tasks tab under "In progress" (or under "Free" when "Who" is "Nobody"), Today "Due today" if it has a date today.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> TaskItem +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> TaskItem +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> TaskItem +1 ~0 -0`. Owner: `import ok store=private zone=<zone> TaskItem +1 ~0 -0`.

Taking, handing back and ticking the task on the other phone give `TaskItem +0 ~1 -0` in the opposite direction.

### 4.4 Event

**Create:** Calendar tab, "+", "New date": "Title", "Starts", "Ends", "Save".

**Look on the other phone:** Calendar tab on that day and under "Upcoming"; Today "Events" when it is today.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> Event +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> Event +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> Event +1 ~0 -0`. Owner: `import ok store=private zone=<zone> Event +1 ~0 -0`.

If the creator shares busy times, a later `BusyInterval` line can follow when Corbie next refreshes busy times (row 4.14). It is not part of this row.

### 4.5 Event comment

**Create:** Calendar, tap the event from row 4.4, section "Comments", type in "Add a comment", "Send".

**Look on the other phone:** The same event's detail screen, "Comments" section.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> EventComment +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> EventComment +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> EventComment +1 ~0 -0`. Owner: `import ok store=private zone=<zone> EventComment +1 ~0 -0`.

### 4.6 Wish in the app

**Create:** Wishes tab, "+", "New wish": "Title", leave "This wish is for me" off (off puts it on the partner's list), "Save".

**Look on the other phone:** Wishes tab, chip "Me" (the wish is for the reader). Today "Waiting for you" shows "Wishes from (name)".

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> Wish +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> Wish +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> Wish +1 ~0 -0`. Owner: `import ok store=private zone=<zone> Wish +1 ~0 -0`.

A wish saved with a link that the server reads later gets a second line, `Wish +0 ~1 -0`, when the fields are filled in.

### 4.7 Wish from the share extension

**Create:** Close Corbie on the creating phone (swipe home, do not force-quit). In Safari open a product page, Share, "Corbie", "Add to Corbie": check "Title", leave "This wish is for me" off, "Save". Wait a minute: there must be no `export` line yet. Then open Corbie on the creating phone.

**Look on the other phone:** Wishes tab, chip "Me".

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> Wish +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> Wish +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> Wish +1 ~0 -0`. Owner: `import ok store=private zone=<zone> Wish +1 ~0 -0`.

The export line appears only after Corbie is opened on the creating phone, because the extension does not sync (`docs/KNOWN_ISSUES.md`). A line before that is a finding.

### 4.8 Big plan with a target

**Create:** Plans tab, segment "Big", "+", "New plan": "Plan type" "With a target", "Title", "Target amount", "Save".

**Look on the other phone:** Plans tab, segment "Big", card under "Active" with "X of Y"; Today "Plans" row.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> Plan +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> Plan +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> Plan +1 ~0 -0`. Owner: `import ok store=private zone=<zone> Plan +1 ~0 -0`.

### 4.9 Open savings plan

**Create:** Plans tab, segment "Big", "+", "New plan": "Plan type" "Open", "Title", "Save".

**Look on the other phone:** Plans tab, segment "Big", the card with "Total".

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> Plan +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> Plan +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> Plan +1 ~0 -0`. Owner: `import ok store=private zone=<zone> Plan +1 ~0 -0`.

### 4.10 Plan step

**Create:** Open the plan from row 4.8, section "Preparation", type in "Add a step", tap "+".

**Look on the other phone:** The same plan, "Preparation", and the "N/M steps" line on its card.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> PlanStep +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> PlanStep +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> PlanStep +1 ~0 -0`. Owner: `import ok store=private zone=<zone> PlanStep +1 ~0 -0`.

Ticking the step on the other phone gives `PlanStep +0 ~1 -0` back.

### 4.11 Contribution (money added to a plan)

**Create:** Open a plan, "Add money" (or the "+" in the bar once the plan has entries), "Amount", "Save". On an open plan, "Taken out" records an expense.

**Look on the other phone:** The plan's "Money" section, a row in the adder's colour; "X of Y" on the card (or "Total" on an open plan).

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> PlanExpense +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> PlanExpense +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> PlanExpense +1 ~0 -0`. Owner: `import ok store=private zone=<zone> PlanExpense +1 ~0 -0`.

No `Plan` line: adding money does not write the plan, the total is counted from the entries.

### 4.12 List

**Create:** Plans tab, segment "Lists", "+", "New list": "Title", "Template" "Shopping", "Save".

**Look on the other phone:** Plans tab, segment "Lists", the new card.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> ChecklistList +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> ChecklistList +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> ChecklistList +1 ~0 -0`. Owner: `import ok store=private zone=<zone> ChecklistList +1 ~0 -0`.

### 4.13 List item

**Create:** Open the list from row 4.12, type in "Add an item", press Return.

**Look on the other phone:** The same list with the item; the card reads "0 of 1 done".

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> ListItem +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> ListItem +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> ListItem +1 ~0 -0`. Owner: `import ok store=private zone=<zone> ListItem +1 ~0 -0`.

Ticking the item on the other phone gives `ListItem +0 ~1 -0` back and shows "ticked by (name)" here.

### 4.14 Busy times

**Create:** Us pill, "Shared settings", "Privacy": switch on "Share my busy times". The phone needs at least one event in the iPhone Calendar in the next 14 days.

**Look on the other phone:** Calendar tab, the clock button at the top right, "When you two are free": the line "(name) hasn't shared their busy times yet" goes away and "Free windows" lists slots once both share.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> BusyInterval +N ~0 -0`, `export ok store=private zone=<zone> Member +0 ~1 -0`. Partner: `import ok store=shared zone=<zone> BusyInterval +N ~0 -0`, `import ok store=shared zone=<zone> Member +0 ~1 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> BusyInterval +N ~0 -0`, `export ok store=shared zone=<zone> Member +0 ~1 -0`. Owner: `import ok store=private zone=<zone> BusyInterval +N ~0 -0`, `import ok store=private zone=<zone> Member +0 ~1 -0`.

`N` is the number of busy ranges from the next 14 days; later refreshes replace them and read `BusyInterval +N ~0 -M`. Titles, places and attendees never appear anywhere, only ranges.

### 4.15 Capsule

**Create:** Us pill, "Capsules", "+", "New capsule": "Title", "Letter", "Opens on" (tomorrow at the earliest), "Save".

**Look on the other phone:** Us pill, "Capsules", under "Coming": "a letter from (name) is waiting".

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> CapsuleItem +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> CapsuleItem +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> CapsuleItem +1 ~0 -0`. Owner: `import ok store=private zone=<zone> CapsuleItem +1 ~0 -0`.

### 4.16 Opening a capsule

**Create:** The next day after 09:00, on the phone the capsule is addressed to: Us pill, "Capsules", the row "ready to open", "Break the seal".

**Look on the other phone:** Us pill, "Capsules", under "Opened": "read by (name)" on the author's phone.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> CapsuleOpen +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> CapsuleOpen +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> CapsuleOpen +1 ~0 -0`. Owner: `import ok store=private zone=<zone> CapsuleOpen +1 ~0 -0`.

Needs a capsule made the day before. Run it for both directions only if each phone made one for the other.

### 4.17 Vote

**Create:** Us pill, "Vote", "+", "New vote": "Question", two "Options", "Save".

**Look on the other phone:** Us pill, "Vote", the row reads "your turn"; Today "Waiting for you".

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> Vote +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> Vote +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> Vote +1 ~0 -0`. Owner: `import ok store=private zone=<zone> Vote +1 ~0 -0`.

Creating a vote does not answer it: the creator also has to answer (next row).

### 4.18 Vote response

**Create:** Tap the vote from row 4.17, pick an option, "Answer".

**Look on the other phone:** Us pill, "Vote": "waiting for (name)" turns into "your turn" for the other person; after both have answered, "you both picked ..." or "you picked different things".

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> VoteResponse +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> VoteResponse +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> VoteResponse +1 ~0 -0`. Owner: `import ok store=private zone=<zone> VoteResponse +1 ~0 -0`.

The answer that completes the vote also gives `Vote +0 ~1 -0` (the reveal).

### 4.19 Person

**Create:** Us pill, "People", "+", "New person": "Name", "Relation", "Save".

**Look on the other phone:** Us pill, "People", the new person.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> Person +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> Person +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> Person +1 ~0 -0`. Owner: `import ok store=private zone=<zone> Person +1 ~0 -0`.

A birthday set here is stored on the person, so it is a `Person` line too.

### 4.20 Person date

**Create:** Us pill, "People", the person from row 4.19, "Dates", "+", "New date": "Title", "Date", "Save".

**Look on the other phone:** The same person's screen under "Dates", and the Calendar on that day.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> PersonDate +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> PersonDate +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> PersonDate +1 ~0 -0`. Owner: `import ok store=private zone=<zone> PersonDate +1 ~0 -0`.

### 4.21 Gift idea

**Create:** The person from row 4.19, "Gift ideas", "+", "New idea": "Title", "Save".

**Look on the other phone:** The same person's screen under "Gift ideas"; Today "Coming up" counts it when a date is near.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> GiftIdea +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> GiftIdea +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> GiftIdea +1 ~0 -0`. Owner: `import ok store=private zone=<zone> GiftIdea +1 ~0 -0`.

Marking it "Picked" on the other phone gives `GiftIdea +0 ~1 -0` back.

### 4.22 Question of the day answer

**Create:** Today tab, the question card, "Answer", "Your answer", "Save".

**Look on the other phone:** Today card: "(name) answered · your turn"; in the sheet the partner's answer reads "Hidden until (name) answers" until both have answered, then both show.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> QuestionAnswer +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> QuestionAnswer +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> QuestionAnswer +1 ~0 -0`. Owner: `import ok store=private zone=<zone> QuestionAnswer +1 ~0 -0`.

Opening Today first makes the day's row on a phone that has none yet (`DailyQuestion +1 ~0 -0` and `Space +0 ~1 -0`), and opening the sheet writes `Member +0 ~1 -0`. If both phones made a row for the same day before seeing each other's, the answers move to one of them (`QuestionAnswer +0 ~1 -0`) and `question consolidation merged <n> rows over <d> days` may follow at launch or on return to the foreground. Either way both answers must show on both phones.

### 4.23 Chore split: the list

**Create:** Us pill, "Chore split", "Start the split". Pick chips until "Continue" is enabled (8 picked), add one with "Add your own".

**Look on the other phone:** Us pill, the "Chore split" tile reads "Building the list"; open it and the same chips are picked, including the custom one.

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> ChoreItem +N ~0 -0`, `export ok store=private zone=<zone> ChoreSet +1 ~0 -0`. Partner: `import ok store=shared zone=<zone> ChoreItem +N ~0 -0`, `import ok store=shared zone=<zone> ChoreSet +1 ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> ChoreItem +N ~0 -0`, `export ok store=shared zone=<zone> ChoreSet +1 ~0 -0`. Owner: `import ok store=private zone=<zone> ChoreItem +N ~0 -0`, `import ok store=private zone=<zone> ChoreSet +1 ~0 -0`.

Each tap in the builder is a write, so more `ChoreItem +0 ~1 -0` lines follow while picking. Run the reverse row with a new split only after the first one is applied (row 4.25), or let the other phone change the same list.

### 4.24 Chore split: ratings

**Create:** Tap "Continue", then rate every card.

**Look on the other phone:** The "Chore split" tile reads "Your turn to rate" before, and after the other phone also finished, "Ready to reveal"; the first to finish sees "Done. Waiting for (name)."

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> ChoreRating +N ~0 -0`, `export ok store=private zone=<zone> ChoreSet +0 ~1 -0`. Partner: `import ok store=shared zone=<zone> ChoreRating +N ~0 -0`, `import ok store=shared zone=<zone> ChoreSet +0 ~1 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> ChoreRating +N ~0 -0`, `export ok store=shared zone=<zone> ChoreSet +0 ~1 -0`. Owner: `import ok store=private zone=<zone> ChoreRating +N ~0 -0`, `import ok store=private zone=<zone> ChoreSet +0 ~1 -0`.

`N` is the number of cards rated since the last export, so the ratings usually arrive in several lines. The `ChoreSet` line comes from "Continue".

### 4.25 Chore split: assignment

**Create:** When both have rated: "See the split", then "Add these to Tasks".

**Look on the other phone:** The tile reads "Applied ..."; the reveal lists "Yours", "(name)'s", "Rotating", "Whoever's around"; Tasks shows the chores with "from the chore split".

- [ ] Owner creates, partner checks. Owner: `export ok store=private zone=<zone> ChoreAssignment +N ~0 -0`, `export ok store=private zone=<zone> ChoreSet +0 ~1 -0`, `export ok store=private zone=<zone> TaskItem +N ~0 -0`. Partner: `import ok store=shared zone=<zone> ChoreAssignment +N ~0 -0`, `import ok store=shared zone=<zone> ChoreSet +0 ~1 -0`, `import ok store=shared zone=<zone> TaskItem +N ~0 -0`.
- [ ] Partner creates, owner checks. Partner: `export ok store=shared zone=<zone> ChoreAssignment +N ~0 -0`, `export ok store=shared zone=<zone> ChoreSet +0 ~1 -0`, `export ok store=shared zone=<zone> TaskItem +N ~0 -0`. Owner: `import ok store=private zone=<zone> ChoreAssignment +N ~0 -0`, `import ok store=private zone=<zone> ChoreSet +0 ~1 -0`, `import ok store=private zone=<zone> TaskItem +N ~0 -0`.

"See the split" and "Add these to Tasks" are two writes, so `ChoreSet` can show twice. On a second split the tasks from the first one are reused and archived, so `TaskItem` reads `+N ~M -0`.

---

## 5. UserPurgedZone

Core Data's own log (subsystem `com.apple.coredata`, so clear the `app.corbie` token to see it) and
the `failed` lines with `code=28` or `code=26` report a zone that is gone. That is expected in these
cases only:

- **The partner leaves the space** (Us pill, Shared settings, Account, Leave space). The partner's log shows
  `purge asked store=shared zone=<zone> reason=leave` and then `purge ok store=shared zone=<zone>
  reason=leave` (or `purge missing ...` when the zone was already gone). Afterwards the partner's
  shared store no longer has that zone. The owner's zone stays.
- **Someone deletes the account** (Us pill, Shared settings, Account, Delete account). That phone shows
  `purge asked store=private zone=<zone> reason=deleteAccount` for every space zone it owns and for
  `com.apple.coredata.cloudkit.zone`, each followed by `purge ok`, `purge missing` or `purge failed`. A
  partner deleting the account also leaves first, so its log starts with the `reason=leave` pair above.
  When the owner deletes the account, the owner's share zone is gone and the partner's phone may report
  it gone too: expected.

Anything else is a bug worth a note: a zone reported gone with no `purge asked` line for that zone
name on either phone in the minutes before. Write down the time, the zone name, and the `sync` lines of
both phones from the minute before.
