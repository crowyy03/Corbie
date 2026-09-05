# Module 06 — Wishes + link parsing + Share Extension

Read spec §6.5, architecture §9, §5 (`/parse`).

## Do
1. `WishesView`: chips {Partner} (default selected) / Me / All; grid or list of cards (thumbnail 64pt, title, price with "≈" in space currency, priority badge, source tag). Empty state per brand + "Paste from clipboard" mono action that reads `UIPasteboard` only on tap.
2. `WishEditorView`: Link field (on paste/URL change → `LinkParser.parse(url)` with 8s timeout, shows skeleton, fills title/price/currency/image); Photo picker fallback; Title; Price + currency menu (space currency first, then USD/EUR/GBP/CHF/CAD); Priority segmented Must have/Want/Someday; Note; toggle "This wish is for me" (off → owner = partner).
3. `LinkParser` (CorbieCore/Services): calls `APIClient.parse(url)`; maps `source` to enum; downloads image, resizes to max 1024px, stores as external binary.
4. Privacy: no "seen" markers anywhere.
5. "Mark as gifted" → fulfilled; "Fulfilled" section collapsed at bottom.
6. **Share Extension** (`CorbieShare`): accepts URL/text; minimal SwiftUI UI (title prefilled from parse, owner toggle, priority); saves through CorbieCore repository into the App Group store; posts widget reload; closes. Handle no-network: save with URL only and flag `needsParse` (app retries on launch).
7. Premium gate on create (except during trial); viewing free in read-only.
8. Analytics: wish_created(source), wish_fulfilled.

## Verify
Paste Amazon, Etsy, Instagram, TikTok links → expected behavior per source. Share from Safari and Instagram app. Both partners see wishes with correct default chip.
