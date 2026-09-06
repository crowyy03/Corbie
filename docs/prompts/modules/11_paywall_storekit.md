# Module 11 — Paywall, StoreKit 2, couple entitlement, 14-day intro trial

Read `docs/01a_SPEC_AMENDMENT_01.md`, spec §6.12, §10; architecture §6, §18 (items 7–9). **This module supersedes the trial mechanics in the base spec** — the trial is now an Apple introductory offer, not a self-managed gate.

## Model in one paragraph
One subscription per **Space**, paid by whichever partner subscribes. The subscriber confirms an Apple **introductory offer of 14 days free** (Face ID / double-click — no card entry, Apple bills the payment method already on the Apple ID). The partner who joins by code pays nothing and confirms nothing. After the trial Apple auto-renews. If billing fails, Apple's grace period keeps access alive while it retries; if it ultimately fails, the space drops to read-only.

---

## 1. Products and offers

`Products.storekit` for local testing, one subscription group `corbie.premium`:

| Product ID | Duration | US price | Intro offer |
|---|---|---|---|
| `app.corbie.yearly` | 1 year | $29.99 | 14 days free |
| `app.corbie.monthly` | 1 month | $4.99 | 14 days free |

- Check eligibility with `Product.SubscriptionInfo.isEligibleForIntroOffer(for:)` before showing any trial copy. If ineligible, the CTA becomes `Subscribe` and the trial line disappears — **never promise a trial the user cannot get**; that is a review rejection.
- Enable **Billing Grace Period** in App Store Connect (console setting, not code — record it in `docs/RELEASE_CHECKLIST.md`). Treat `.inGracePeriod` as premium.

## 2. Three screens, not one

### 2.1 `TrialOfferView` — after onboarding, once
Shown **after** the profile step and the invite screen. Never the first thing the user sees.

- Headline: `One subscription. Both of you.` Sub: `Your partner pays nothing.`
- Six value lines, icon + short text, no checkmark clutter: a shared calendar and dates · tasks either of you can pick up · wishes that fill in from a link · goals and open savings · a question a day, answers unlock together · everything on your home screen
- `PlanSelector` (§2.3) with **yearly preselected**.
- Primary CTA: `Try 14 days free` (or `Subscribe` when ineligible).
- Legal line directly under the CTA: price, period, `renews automatically`, `cancel anytime in Settings` — built from `Product.displayPrice`, never hardcoded.
- Footer row: `Restore` · `Privacy` · `Terms`.
- Quiet low-contrast link at the very bottom: `Continue without a subscription` → `ComparisonView`. Required for review and for users who won't attach billing; present but not loud.

### 2.2 `ComparisonView` — the Free / Premium table
Reached from the quiet link and shown when the trial or subscription ends. Two columns, **seven rows maximum** so it fits an iPhone SE without scrolling.

| Free | Premium |
|---|---|
| Shared calendar | Everything in Free |
| Today screen | A question a day, 1000 of them |
| Weekly recap | Wishes that fill in from a link |
| See everything you've already made | Goals, open savings, multi-currency |
| | Capsules and secret votes |
| | Chore split by preference |
| | 30+ widgets and "when we're both free" |

Same `PlanSelector` and CTA below the table. Header when arriving after expiry: `Your trial has ended. Everything you made is still here.`

### 2.3 `PlanSelector` component
Two cards, yearly on top and visually dominant.

- **Yearly** — `$29.99 / year`, struck-through `$59.88` beside it, badge `−50%`, sub-line `$2.49 per month`.
- **Monthly** — `$4.99 / month`, smaller card, no badge.

**Compute the struck-through amount and the discount percentage at runtime** from `monthlyProduct.price * 12`, formatted with the product's own currency and locale. Never hardcode `$59.88` or `50%` — storefront prices differ, and a dollar sign shown in Germany is both a rejection and a trust problem.

Selected state uses `ice`, unselected uses `border`. Tapping selects; the CTA acts on the selection.

## 3. Purchase flow

```swift
let result = try await product.purchase(options: [.appAccountToken(space.id)])
```
- `appAccountToken` is **always** `Space.id`. Without it the server cannot map the transaction to the space and the partner never becomes premium.
- `.success(verification)` → verify via `Transaction.verified`, finish the transaction, refresh entitlement, dismiss.
- `.userCancelled` → no error UI. `.pending` (Ask to Buy) → show a `Waiting for approval` state and keep listening.
- Start a detached task at launch listening to `Transaction.updates` for the app's lifetime.
- `Restore`: `try await AppStore.sync()`, then refetch entitlement by spaceId.

## 4. Entitlement for two people

`EntitlementService`:
```
isPremium =
    localStoreKitEntitlement.isActive          // fast path, subscriber's device only
 || serverEntitlement.isActive                  // source of truth for both partners
 || space.cachedSubscriptionStatus.isActive     // offline fallback from CloudKit
```
- Server call `GET /entitlement/{spaceId}` on launch, on foreground, after any purchase, and hourly.
- Premium statuses: `active`, `inGracePeriod`, and `inBillingRetry` only while still within grace.
- Mirror resolved status and `expiresAt` into `Space.subscriptionStatus` / `subscriptionExpiresAt` (CloudKit) so the non-paying partner stays premium offline.
- **The partner has no transaction on their Apple ID.** Never gate them on `Transaction.currentEntitlements`.

## 5. Read-only mode after expiry

`PremiumGate` exposes `isReadOnly`.

- **Everything renders.** Tasks, wishes, goals, lists, capsules, questions, People — all visible with their data. Never blank a screen the user filled.
- **No padlock icons on rows.** Locks on every line read as begging and destroy trust.
- **Gate the action, not the view.** `+` buttons, checkboxes, editors and the chore/capsule/vote flows call `PremiumGate.require(_:)`, which presents `ComparisonView` with a contextual header, e.g. `Unlimited tasks are part of Premium.`
- **Calendar stays fully functional** — create, edit, delete, reminders, import. Deliberate; verify explicitly before submission.
- **Today and the weekly recap stay visible**, inline actions gated.
- Widgets: `DaysTogether` and `Countdown` keep working; the rest render `Unlock in Corbie` with a deep link.

## 6. Trial lifecycle and notifications

- `trialEndsAt` comes from StoreKit (`Transaction.expirationDate` during the intro period), never from our own clock.
- Local notification **2 days before** the trial ends: `Your trial ends in 2 days` / `Corbie stays $29.99 a year for both of you.` Always-on system notice rather than a user toggle. Reduces refunds and chargebacks, and it is simply honest.
- Dismissible banner on Today when ≤2 days remain.
- On expiry: one notification, then silence. Never nag daily.

## 7. Debug menu (DEBUG builds only)

Force states: `premium`, `trial with 2 days left`, `expired / read-only`, `ineligible for intro offer`, `grace period`. Every state below must be reachable without waiting real days.

## 8. Analytics

`trial_offer_shown`, `trial_started(product)`, `comparison_shown(reason)`, `plan_selected(product)`, `purchase_started(product)`, `purchase_completed(product, isTrial)`, `purchase_failed(reason)`, `restore_tapped`, `readonly_hit(feature)`, `paywall_dismissed(screen)`, `grace_period_entered`.

## 9. Verify

- Sandbox device A: purchase yearly with trial → device B (different Apple ID, joined by code) becomes premium **without any purchase**, within a minute.
- Struck-through price and discount badge render correctly in `en_US`, `de_DE`, `fr_FR` sandboxes with correct currency and separators.
- An Apple ID that already used the intro offer sees `Subscribe`, not `Try 14 days free`.
- Force expiry from the debug menu: everything still visible, `+` opens the comparison, **calendar still fully editable**.
- Cancel in sandbox → expiry → read-only; resubscribe → premium restored on both devices.
- Ask to Buy (sandbox family account) → pending handled, no crash, no double charge.
- Restore on a fresh install of the subscriber's device returns premium.

## 10. App Review checklist for this module

Price, duration and `renews automatically` on the same screen as the CTA · Restore present · Privacy and Terms links present · no trial promise for ineligible users · user data never hidden behind the paywall · no mention of any non-Apple payment method.
