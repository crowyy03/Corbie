# Every way pairing can fail, and how to tell which one happened

Written on 2026-09-19 after a two device pairing attempt that failed with nothing on screen. Updated
on 2026-09-21 after the next one: the owner tapped Invite three times because nothing seemed to happen,
which made three codes (FYDW7C, JHQ6FU, XAQ5Y9), and the partner kept typing one that a newer code had
already killed and was told it had expired.

Every step below now says something on screen and writes one line to the device log. Open Console on
a Mac, select the iPhone, filter on `app.corbie`, and read the four categories:

| Category | What it tells you |
| --- | --- |
| `storage` | one line per process at launch: the App Group container, the defaults round trip, the keychain |
| `server` | one line per process at launch: the base URL this build talks to |
| `pairing` | every step of an invite or a join, and the reason when one fails |
| `keychain` | only when an item is refused, with the OSStatus |

The log lines are English and fixed, so they can be grepped. The screen text is localized.

## The owner makes a code

| Step | What goes wrong | What the person sees | Log line |
| --- | --- | --- | --- |
| Onboarding, before the invite step | The space already has two members: the local store holds a partner row beside this member (the second phone of someone already paired) | no invite step: after the profile step, or after backing out of a code, onboarding goes straight to Today; no code is made, no share is asked for, nothing is stored | `invite: step skipped, the space already has two members` |
| Onboarding, before the invite step | The store has the space but no partner row yet (a second phone still importing) | the screen stays as it is with Continue disabled; after 0.4 s a spinner with "checking iCloud" takes its place. The wait ends at the first of: the partner row lands (then the row above: Today, no code), an import into the store that holds the space finishes and a re-read still finds no partner, or 3 seconds. The last two open the invite step as before | `invite: waited <n> ms for iCloud, partner found`, `... partner none`, `... partner none, import failed: <reason>` or `... timed out` |
| Onboarding, before the invite step | Waiting cannot help: the space was made on this phone during this onboarding, the build does not mirror to CloudKit (tests, previews), or iCloud has no account or is temporarily unavailable | the invite step at once, as before | `invite: waited <n> ms for iCloud, skipped, <reason>` with `space made on this phone`, `no CloudKit mirroring`, `no iCloud account` or `iCloud busy` |
| Before anything | Not signed in to iCloud | "Sign in to iCloud on this iPhone, then try again." | `invite failed as signedOutOfICloud` |
| Before anything | iCloud account temporarily unavailable | "iCloud is not ready on this iPhone. Try again in a minute." | `invite failed as iCloudBusy` |
| `CloudKitSharing.share` | CloudKit refuses to make the share (network, quota, anything) | the sentence for that reason | `share create: <reason>: CKError <n> <text>` |
| `CloudKitSharing.share` | The share saved but iCloud has not given it a URL yet | "iCloud has not published the invite link yet. Try again in a moment." | `share for space <id> saved, url pending`, then `invite failed as sharePending` |
| `POST /invite` | The session token is missing or no longer valid | "Sign in again to continue." | `invite failed as signInAgain` |
| `POST /invite` | Thirty invites already made from this space | "Too many tries. Wait a minute." | `invite failed as throttled` |
| `POST /invite` | Offline, or the server answered 5xx | "No answer from the network." | `invite failed as network` |
| `POST /invite` | The build carries no server URL | "This build has no server address." | `invite failed as serverMissing` |
| All good | | the six character code and the countdown | `invite: code <CODE> is ready` |
| Opening the invite screen again | A live code exists for this space | the same code and what is left of its fifteen minutes, nothing new is made | `invite: showing the live code <CODE> again` |
| Opening the invite screen again | The stored code expired, or belongs to another space | a new code | `invite: code <CODE> is ready` |
| "New code" | The person asks for another code | a new code; the line under the button says the old one stops working at once | `invite: code <CODE> is ready` |
| While the screen is open | The partner joins | the code, the countdown and "New code" give way to "<Name> joined", and 1.5 seconds later (at once with Reduce Motion) the screen closes on Today | `invite: partner joined` |
| Opening the invite screen again | The partner joined while it was closed | "<Name> joined" straight away, then Today | `invite: partner joined` |
| Onboarding | The partner row cannot be read from the local store | the code stays, nothing reacts; during the wait for iCloud a failed read counts as no partner | `invite: partner lookup failed: <reason>` |

The live code (code, expiry, space id, and the partner already in the space when it was made, if any)
is kept in the App Group defaults under `corbie.pairing.liveInvite`, so closing the sheet or killing the
app does not lose it. Only "New code", "Try again" after a failure, or a missing or expired code makes a
new one. Asking for a new code forgets the stored one first, so a request that fails halfway never
brings back a code the server may already have replaced. A partner joining forgets it too, since it
has been used.

The screen does not ask iCloud about the partner, it watches what the app already knows. Signed in
(Settings, the Today empty state), that is the session's partner, which `AppEnvironment` picks up on
the next synced change or on foreground. In onboarding there is no session yet, so the onboarding reads
the space's partner row from the local store before it would open the invite step. When one is there
it skips the step (the first row above). When none is there and waiting can help, it waits up to 3
seconds for iCloud (the second row): it reads the row again on every stored change and when an import
into the store that holds the space finishes. An import already running when the wait starts counts,
since the space row usually lands in the middle of one; one that finished before does not. Then it
opens the step and reads the row again on every change that arrives from iCloud. Only a member of this space counts, and not the one who was already
there when the code was made, so a phone that joins another space does not see its own old invite
flip. A space that already has two members does not get this screen from anywhere: onboarding skips
it, and Settings and the Today empty state offer the invite only while there is no partner.

Timings, one line each, category `pairing`: `invite: create the share took <n> ms` (the CloudKit share)
and `invite: POST /invite took <n> ms`. Each also writes `<name> started` when it begins and
`<name> failed after <n> ms` when it throws.

## The partner joins with the code

| Step | What goes wrong | What the person sees | Log line |
| --- | --- | --- | --- |
| Before anything | Not signed in to iCloud, or iCloud busy | the same two sentences as above | `join failed as signedOutOfICloud` / `iCloudBusy` |
| `GET /invite-redeem` | Wrong code | "No space answers to that code." | `join failed as notFound` |
| `GET /invite-redeem` | A newer code of the same space replaced it (`410 superseded`) | "A newer code replaced this one. Use the code on your partner's screen now." | `join failed as superseded` |
| `GET /invite-redeem` | Used by another phone, or by this one more than fifteen minutes ago (`409 redeemed`) | "That code was already used. Ask for a new one." | `join failed as redeemed` |
| `GET /invite-redeem` | Older than fifteen minutes (`410 expired`) | "That code expired. Ask for a new one." | `join failed as expired` |
| `GET /invite-redeem` | This phone redeemed it less than fifteen minutes ago (the app was killed during the join) | nothing, the join carries on with the same share | `join: redeem the code took <n> ms` |
| `GET /invite-redeem` | Too many tries | "Too many tries. Wait a minute." | `join failed as throttled` |
| The stored invite | The row carries no share link | "That invite is gone from iCloud. Ask for a new code." | `join failed as shareMissing` |
| `fetchShareMetadata` | The share or its zone is gone on the server | "That invite is gone from iCloud. Ask for a new code." | `fetch share metadata: missing: CKError <n>`, then `join failed as shareMissing` |
| `fetchShareMetadata` | Not signed in, or no network | the iCloud or network sentence | `fetch share metadata: notSignedIn|network: CKError <n>` |
| Owner check | Both phones are on the same iCloud account | "That code comes from this same iCloud account. Pairing needs two." | `join failed as ownAccount` |
| `acceptShare` | CloudKit refuses the invitation | the sentence for that reason | `accept share: <reason>: CKError <n> <text>` |
| Waiting for the space | The shared space does not arrive within 15 seconds | "iCloud has not sent the space yet. Stay online and try again." | `join failed as spaceLate` |
| Saving the member row | Saved, but iCloud did not confirm the upload within 20 seconds | "You are in. Your partner sees you once iCloud syncs." | `join: member upload not confirmed` |
| All good | | "You two are connected" | `join: member upload finished` |

## What the partner sees while joining

The spinner has the step it is on under it, and every step writes `<name> started` when it begins and
`<name> took <n> ms` or `<name> failed after <n> ms` when it ends, so a device session gives the real
time of the metadata fetch and of `acceptShare`.

| Step on screen | Log name | What runs |
| --- | --- | --- |
| checking the code | `join: redeem the code` | `GET /invite-redeem/{code}` with `X-Anon-Id` |
| finding the invite in iCloud | `join: fetch share metadata` | `CloudKitSharing.fetchShareMetadata` |
| finding the invite in iCloud | `join: check the share owner` | `isOwnShare`, the same iCloud account check |
| accepting the invite | `join: accept share` | `CloudKitSharing.acceptShare` |
| waiting for the space from iCloud | `join: wait for the space` | up to 30 reads, 500 ms apart |
| waiting for the space from iCloud | `join: drop the local space` | deleting the partner's own empty space |
| saving you to the space | `join: save the member` | the member row and the together-since date |
| saving you to the space | `join: reload the session` | `AppEnvironment.reloadSession` |
| waiting for the upload to iCloud | `join: wait for the member upload` | up to 20 seconds for the export |

Before the first step (the checks for a local space and the iCloud account) the line reads "joining".

## Storage, which breaks everything quietly

`StorageProbe` runs at launch in the app, the widgets and the share extension. It checks the App Group
container, writes and reads back a value in the shared defaults, and writes and deletes a keychain
item in the shared access group.

| What goes wrong | What the person sees | Log line |
| --- | --- | --- |
| The App Group is not reachable | "This build cannot reach its shared storage." at launch, and the Developer section shows the details | `app storage: no app group container, ...` |
| The shared defaults cannot be read back | the same toast | `app storage: ..., defaults unreadable, ...` |
| The keychain refuses the shared access group | the same toast | `app storage: ..., keychain refused group.app.corbie, status -34018` plus a `keychain` line per item |

A keychain item refused with `-34018` is written again without the shared access group, so the app
keeps working; the extensions then have their own copy instead of the shared one.

The store itself failing to load (`CoreDataStack.loadFailure`) shows the same toast. Before 2026-09-19
nothing read that value, so a phone that could not open the App Group silently kept its data in a
private folder that the widgets and the share extension could not see.

## What is still not covered

- The owner's invite screen reacts only as fast as the app learns about the partner: signed in, on
  the next synced change or foreground; in onboarding, on the next change merged from iCloud. There is
  still no "waiting for your partner" line while the code is up.
- A partner who accepts the share from the Messages link rather than the code goes through
  `Router`, not through this path, and only the CloudKit errors above are surfaced there.
- None of this ran on two real phones yet. The lines above come from reading the code and from the
  simulator. The 2026-09-21 changes (the live code, "New code", `superseded`, the same phone retry,
  the steps and their timings) are covered by unit and server tests only; the server half needs
  migration 0008 and a function deploy before a phone can see it. The owner's joined state
  (2026-09-22) is covered by unit tests only and has not run in the simulator either. The onboarding
  skip for a space of two (2026-09-22) has unit tests that compile; they had not run when it was written.
  The same holds for the wait for iCloud before the invite step (2026-09-23).
- Onboarding waits at most 3 seconds for iCloud before the invite step (2026-09-23). A second phone
  whose partner row arrives later than that, or after an import into its store finished without it,
  still shows the invite step and makes a code; when the row arrives the screen says "<Name> joined"
  and moves to Today, the right place with the wrong sentence. How often 3 seconds is enough on a real
  second phone is not known yet: nothing of the wait ran on a device. A second phone that has not
  received the space at all yet makes a new space of its own, as before.
