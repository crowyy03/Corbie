# Module 11 — Paywall, StoreKit 2, couple entitlement

Read spec §6.12, §10; architecture §6, §18 (7–9).

## Do
1. `Products.storekit` config for local testing with `app.corbie.monthly` ($4.99) and `app.corbie.yearly` ($29.99), one group.
2. `StoreService` (CorbieCore): load products, `purchase(product, appAccountToken: space.id)`, listen to `Transaction.updates`, `AppStore.sync()` for restore.
3. `EntitlementService`: `isPremium` = `space.trialActive || serverEntitlement.active || localEntitlement.active`. Fetch `GET /entitlement/{spaceId}` on launch, foreground, and after purchase; cache in Keychain and mirror to `Space.subscriptionStatus/expiresAt` (CloudKit) so the partner sees it offline.
4. `PremiumGate`: `require(.create)` → if not premium present `PaywallView` with reason; `readOnly` state exposed to views to swap "+" actions.
5. `PaywallView`: headline "One subscription. Both of you.", three value rows, Yearly (badge "Save 50%") and Monthly, Continue, auto-renew legal text, Restore, Privacy/Terms links. Trigger points: trial expired + create attempt; Settings; banner "Trial ends in N days" (N≤2) on tabs.
6. Read-only mode: all views render; create/edit CTAs route to paywall; Calendar remains fully functional (verify explicitly).
7. Analytics: paywall_shown(reason), trial_started, purchase(product), restore, readonly_hit.

## Verify
Sandbox: purchase on device A → server entitlement → device B becomes premium without purchase. Expire trial via debug menu → read-only; calendar still editable; restore works.
