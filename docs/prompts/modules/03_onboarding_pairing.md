# Module 03 — Onboarding, Sign in with Apple, pairing

Read spec §6.1, §6.2, §3 and architecture §4.

## Goal
User signs in, creates a Space (solo-first), invites partner with a 15-minute code; partner joins and both see one Space.

## Do
1. Onboarding: 3 swipeable pages (copy from spec/brand), then `SignInWithAppleButton`. On success store `userIdentifier` in Keychain; create `Member` (displayName from Apple name if provided) and `Space` if none exists (via `CloudKitSharing.currentSpace()`).
2. Profile step: name field, color picker (6 cold hues), "Together since" (optional), birthday month/day (optional; explain radar).
3. Invite screen: big code (6 chars) fetched from `APIClient.createInvite(shareURL:spaceId:)` after generating `CKShare` (Module 02). Countdown "expires in 14:59". Buttons: "Share code" (ShareLink with text "Join me on Corbie: corbie.app/join/CODE") and "Later".
4. Join flow: "Have a code?" field (onboarding and Settings). On submit → `APIClient.redeemInvite(code)` → shareURL → fetch `CKShare.Metadata` via `CKContainer.shareMetadata(for:)` → `acceptShare`. Show progress; on success route to Tasks with toast "You two are connected".
5. Universal link `https://corbie.app/join/{code}` and URL scheme `corbie://join/{code}` → join flow prefilled.
6. **No self-managed trial.** Do not set `trialEndsAt` here — the trial is an Apple introductory offer handled entirely by StoreKit in Module 11, and `trialEndsAt` is read from `Transaction.expirationDate`. After the invite screen, route to `TrialOfferView` (Module 11; stub it here so the flow is wired).
7. Handle Apple credential revocation → sign out, keep local data.
8. Analytics events: `onboarding_step`, `space_created`, `invite_created`, `invite_redeemed` via `Analytics` stub (Module 13 implements transport).

## Verify (two physical devices, two Apple IDs)
A signs in → creates space → invites. B signs in → enters code → sees A's space. A adds a placeholder task (temporary debug button) → appears on B. B leaves space → disappears. Document results in `docs/DECISIONS.md`.
