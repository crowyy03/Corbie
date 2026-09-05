# Module 01 — Design system

Read `docs/02_BRAND_BOOK.md` §5–§8.

## Goal
`CorbieCore/Design` with tokens and reusable components, used by all targets.

## Do
1. `Colors.swift`: `CorbieColor` enum with static `Color` values for both schemes using `Color(light:dark:)` helper via `UIColor { traits in }`. Tokens: bg, surface, elevated, border, text, text2, ice (accent), warn (#E8956F), partner palette of 6 cold hues (keys `p1…p6`; defaults: A=#6FB1E3, B=#A98FE0). Expose `Color.corbie.<token>`.
2. `Typography.swift`: `CorbieFont` with `screenTitle` (SF Pro Display Bold 34), `sectionCaps` (SF Mono 12, uppercase, tracking 1.2), `body`, `caption`, `mono` (SF Mono 13), `counter` (SF Pro Rounded Heavy 56, monospaced digits). Provide `View` modifiers.
3. Components (SwiftUI, previews for light/dark):
   - `PrimaryButton` (full-width, `text` on `ice`? No: white text on `#E6EDF5` background in dark theme like You&Me's white pill; on light theme `#0B0E13` background). Height 56, corner 28.
   - `SecondaryButton` (outlined, border token).
   - `Card` container (surface, corner 20, padding 16).
   - `SectionCaps(text:)` label.
   - `EmptyState(icon:title:subtitle:monoNote:cta:)` — one sentence title, one line subtitle, mono note, CTA.
   - `MemberDot(color:size:)` and `UsPill(colorA:colorB:)`.
   - `ProgressBar(value:overspend:)` — ice fill; if overspend > 0 draw warn segment past 100%.
   - `SegmentedPicker` styled to brand (3 options).
   - `Chip(label:count:isSelected:tint:)` — for filters.
   - `Toast` presenter (non-blocking, bottom).
4. `Theme.swift`: `preferredColorScheme` from user setting (system/light/dark) stored in `UserDefaults(suiteName: appGroup)`.
5. Xcode Previews for every component in both schemes.

## Verify
Build all targets. Previews render. No hardcoded hex outside `Colors.swift`.
