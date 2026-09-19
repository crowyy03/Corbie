# Every way pairing can fail, and how to tell which one happened

Written on 2026-09-19 after a two device pairing attempt that failed with nothing on screen.

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
| Before anything | Not signed in to iCloud | "Sign in to iCloud on this iPhone, then try again." | `invite failed as signedOutOfICloud` |
| Before anything | iCloud account temporarily unavailable | "iCloud is not ready on this iPhone. Try again in a minute." | `invite failed as iCloudBusy` |
| `CloudKitSharing.share` | CloudKit refuses to make the share (network, quota, anything) | the sentence for that reason | `share create: <reason>: CKError <n> <text>` |
| `CloudKitSharing.share` | The share saved but iCloud has not given it a URL yet | "iCloud has not published the invite link yet. Try again in a moment." | `share for space <id> saved, url pending`, then `invite failed as sharePending` |
| `POST /invite` | The session token is missing or no longer valid | "Sign in again to continue." | `invite failed as signInAgain` |
| `POST /invite` | Thirty invites already made from this space | "Too many tries. Wait a minute." | `invite failed as throttled` |
| `POST /invite` | Offline, or the server answered 5xx | "No answer from the network." | `invite failed as network` |
| `POST /invite` | The build carries no server URL | "This build has no server address." | `invite failed as serverMissing` |
| All good | | the six character code and the countdown | `invite: code <CODE> is ready` |

## The partner joins with the code

| Step | What goes wrong | What the person sees | Log line |
| --- | --- | --- | --- |
| Before anything | Not signed in to iCloud, or iCloud busy | the same two sentences as above | `join failed as signedOutOfICloud` / `iCloudBusy` |
| `GET /invite-redeem` | Wrong code | "No space answers to that code." | `join failed as notFound` |
| `GET /invite-redeem` | Older than fifteen minutes | "That code expired. Ask for a new one." | `join failed as expired` |
| `GET /invite-redeem` | Already used | "That code was already used. Ask for a new one." | `join failed as redeemed` |
| `GET /invite-redeem` | Too many tries | "Too many tries. Wait a minute." | `join failed as throttled` |
| The stored invite | The row carries no share link | "That invite is gone from iCloud. Ask for a new code." | `join failed as shareMissing` |
| `fetchShareMetadata` | The share or its zone is gone on the server | "That invite is gone from iCloud. Ask for a new code." | `fetch share metadata: missing: CKError <n>`, then `join failed as shareMissing` |
| `fetchShareMetadata` | Not signed in, or no network | the iCloud or network sentence | `fetch share metadata: notSignedIn|network: CKError <n>` |
| Owner check | Both phones are on the same iCloud account | "That code comes from this same iCloud account. Pairing needs two." | `join failed as ownAccount` |
| `acceptShare` | CloudKit refuses the invitation | the sentence for that reason | `accept share: <reason>: CKError <n> <text>` |
| Waiting for the space | The shared space does not arrive within 15 seconds | "iCloud has not sent the space yet. Stay online and try again." | `join failed as spaceLate` |
| Saving the member row | Saved, but iCloud did not confirm the upload within 20 seconds | "You are in. Your partner sees you once iCloud syncs." | `join: member upload not confirmed` |
| All good | | "You two are connected" | `join: member upload finished` |

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

- The owner's invite screen does not react when the partner joins: the session reloads on the next
  synced change or foreground, and the code screen has no "waiting for your partner" state.
- A partner who accepts the share from the Messages link rather than the code goes through
  `Router`, not through this path, and only the CloudKit errors above are surfaced there.
- None of this ran on two real phones yet. The lines above come from reading the code and from the
  simulator.
