# Module 15 — QA pass and App Store submission

Read `docs/01a_SPEC_AMENDMENT_01.md`, architecture §16, spec §12, §15.

## Do
1. Test matrix: iPhone SE (3rd), iPhone 15, iPhone 15 Pro Max; iOS 17.0 and latest; **all three themes** (full pass in Sand and Deep, sweep in Sage for contrast and clipping); member colour picker blocks the incompatible pairs on both devices; EN + DE; Dynamic Type XL. Run one pass with Deuteranopia colour filters on to confirm partner dots stay distinguishable.
2. Two-Apple-ID scenarios (must pass): create → invite → join → edits propagate both ways within 5s on Wi-Fi → widgets update → partner leaves → owner deletes space → both reset.
3. Purchase scenarios in sandbox: yearly with 14-day intro trial, monthly, restore, expiration → read-only, partner entitlement without purchase, upgrade monthly→yearly, Ask to Buy pending, grace period, an Apple ID ineligible for the intro offer (must see `Subscribe`, not a trial promise). Verify struck-through price and discount render correctly in en_US, de_DE and fr_FR.
4. Permission-denied paths: notifications, calendar, photos, location — no dead ends.
4a. Privacy audit for free-time: inspect CloudKit Dashboard and confirm no `BusyInterval` record carries a title, location or attendee; confirm disabling the toggle removes records.
4b. Today screen vs `OurDay` widget: same items, same order, in three data states (empty, light, full).
5. Offline: create/edit everything offline → reconnect → sync without duplicates.
6. App Review checklist: paywall shows price, period, auto-renew text, Restore, Privacy/Terms; Sign in with Apple works; account deletion present; privacy nutrition labels set (Usage Data, Diagnostics — not linked); no placeholder text; no crashes on first launch without network.
7. Store assets: icon (two ravens), 6 screenshots per size, preview video 20s, metadata per language, keywords, age rating questionnaire (4+), export compliance (uses standard encryption → exempt).
8. Prepare `docs/RELEASE_CHECKLIST.md` and fill it in.

## Report
List all defects found and fixed; anything remaining goes to `docs/KNOWN_ISSUES.md` with severity.
