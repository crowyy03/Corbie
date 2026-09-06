# Module 01 — Design system, 3 themes, member colour picker

Read `docs/02_BRAND_BOOK.md` §5–§8. Every hex is specified there; **copy them verbatim — do not invent, round or "improve" any value.** They were chosen together and verified for contrast and colour-blind separation.

## Goal
`CorbieCore/Design`: a theme engine, a member-colour system, and reusable components shared by app, widgets and share extension.

## 1. Theme engine

1. `CorbieTheme` — enum with three cases: `sand`, `sage`, `deep`. Properties: `displayNameKey`, `isDark` (true only for `deep`).
2. `ThemePalette` — struct of `Color` tokens: `bg`, `surface`, `elevated`, `border`, `text`, `text2`, `accent`, `ctaFill`, `ctaText`, `warn`, plus `memberColors: [MemberColorSlot: Color]`.
3. `MemberColorSlot` — enum: `teal`, `blue`, `violet`, `rose`, `clay`, `green`. Codable by raw string; this is what `Member.colorKey` stores.
4. `ThemeStore` — persists to `UserDefaults(suiteName: "group.app.corbie")` so widgets and the share extension resolve the same theme. Keys: `theme`, `autoTheme` (Bool), `autoLightTheme`, `autoDarkTheme`.
5. Resolution: if `autoTheme` is on, choose `autoLightTheme` / `autoDarkTheme` from the current `colorScheme`; otherwise use `theme`. Expose via `@Observable ThemeProvider` in the environment; views read `\.palette`.
6. First-launch defaults: `autoTheme = true`, `autoLightTheme = .sand`, `autoDarkTheme = .deep`.
7. When `autoTheme` is off, force the window's `preferredColorScheme` to match `isDark` so keyboards, sheets and the status bar follow. When on, pass `nil`.

## 2. Member colours

- `Member.colorKey: String` stores a **slot**, never a hex. `palette.memberColors[slot]` resolves it.
- Defaults: space creator `teal`, joining partner `rose`.
- **Incompatible pairs** — a shared constant in `CorbieCore`, identical across themes plus one Deep-only extra:
  ```
  teal+blue, blue+green, violet+rose, rose+clay        // all themes
  teal+green                                           // deep only
  ```
  Implement as `MemberColorSlot.conflicts(with:in:) -> Bool`.
- **Colour picker** (used in onboarding and Settings): a row of six swatches rendered in the *current* theme. A slot that conflicts with the partner's current slot is shown at 35% opacity, is not tappable, and carries the accessibility label `too close to {Partner}'s colour`. The partner's own slot shows a small check and the same treatment. Changing your colour never changes theirs.
- Validate in the repository layer as well, not only the UI — a CloudKit sync race must not leave both members on a conflicting pair. If it happens, the joining member's colour is shifted to the nearest free non-conflicting slot and a toast explains it.

## 3. Hard rules

- **No hex literal outside `Palettes.swift`.** Add `scripts/check_colors.sh` that greps `Corbie/` and `CorbieWidgets/` for `Color(red:`, `#colorLiteral` and 6-digit hex strings and fails the build. Wire it into the build phase.
- **No system colours in views** — no `.blue`, `.pink`, `.red`, `.accentColor`. Semantic tokens only.
- `warn` is used **only** for over-budget amounts and destructive actions.
- Lock-screen widgets are monochrome: never encode ownership in colour there — use shape, position or an initial.

## 4. Typography

`CorbieFont`: `screenTitle` (SF Pro Display Bold 34, tight tracking), `sectionCaps` (SF Mono 12, uppercase, tracking 1.2), `body` (SF Pro Text 17), `caption` (15), `mono` (SF Mono 13, helper sub-lines), `counter` (SF Pro Rounded Heavy 56, monospaced digits). Provide `View` modifiers. All scale with Dynamic Type; `counter` caps at XXL to protect layout.

## 5. Components

Each with previews across **all three themes**, light and dark system settings (use a `PreviewThemes` helper that loops the enum):

- `PrimaryButton` — height 56, corner 28, `ctaFill` background, `ctaText` label.
- `SecondaryButton` — `border` outline, `text` label.
- `Card` — `surface`, corner 20, padding 16.
- `SectionCaps(text:)`.
- `EmptyState(icon:title:subtitle:monoNote:cta:)`.
- `MemberDot(slot:size:)`, `UsPill(slotA:slotB:badge:)`.
- `MemberColorPicker(selected:partnerSlot:)` — §2 behaviour.
- `ProgressBar(value:overspend:)` — `accent` fill, overspend past 100% in `warn`.
- `SegmentedPicker`, `Chip(label:count:isSelected:tint:)`, `PlanCard`, `Toast`.

## 6. Theme picker (Settings)

Three preview cards, each a miniature of the real thing: background, a surface card, two member dots, an accent bar — not a flat colour chip. Selecting applies instantly with a 200 ms crossfade. Above them a `Match system appearance` toggle; when on, two compact pickers appear for the light and dark choice.

## Verify
- Every component preview renders correctly in Sand, Sage and Deep.
- `scripts/check_colors.sh` passes clean and fails when a hex is introduced.
- Changing theme updates the app instantly and the widget on next reload.
- Colour picker: pick `teal` on device A → on device B, `teal`, `blue` and (in Deep) `green` are disabled with the right label.
- Simulator with Deuteranopia colour filters on: every allowed pair is still distinguishable.
- Dynamic Type XXXL: nothing clipped in buttons, chips or counters.
