# Module 12 — Settings, notifications, account lifecycle

Read spec §6.11, §9, §15; architecture §8, §14, §18 (13–14).

## Do
1. `SettingsView` sections per spec: You (name, color, birthday), Partner, Our dates (together since, wedding), Notifications (9 toggles, stored in Member.notificationPrefs), Space currency, Import from iPhone Calendar (Module 05), Subscription (status/manage/restore), Privacy (copy + links), Export my data (JSON via ShareLink), Leave space, Delete account, Theme (system/light/dark), version.
2. `NotificationCenterService`: request permission after first joint action (a task done by partner or wish added by partner), not at onboarding. Categories with actions: TASK (Take/Done), VOTE (Vote). Register `CKDatabaseSubscription` for private and shared DBs (silent push); on remote notification → fetch changes → post local notification according to prefs and change type (compare snapshots via persistent history).
3. Export: serialize all Space entities to JSON (DTOs), write to temp, share.
4. Delete account: leave/delete space (Module 02), delete Keychain identity, revoke Sign in with Apple token via `APIClient.revokeApple(token)` (server function), wipe local stores, return to onboarding.
5. Legal: Privacy Policy and Terms as hosted URLs (`https://corbie.app/privacy`, `/terms`) with in-app SafariView.

## Verify
All 9 notification types fire in the right situations with prefs respected; export produces valid JSON; delete account fully resets.
