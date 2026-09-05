# Module 14 — Localization (EN, ES, FR, DE, IT)

Read spec §14, brand §5.

## Do
1. Audit: every user-facing string must be a String Catalog key `feature.screen.element`. Fail the build if any literal string is found in Views (add a simple script `scripts/check_strings.sh` grepping `Text("` with non-key literals).
2. Translate all keys to ES, FR, DE, IT preserving tone (short, dry, no exclamation marks). Keep product nouns in English where natural (Corbie). Plural rules via `String(localized:)` with `%lld` and `.stringsdict` equivalents in the catalog.
3. Dates, numbers, currency via Locale everywhere; verify first weekday per locale; verify currency symbol placement for EUR in de_DE vs fr_FR.
4. Widgets and Share extension localized via the same catalog.
5. App Store metadata drafts for 5 languages in `docs/store/{lang}.md`: name, subtitle, keywords (100 chars), description, what's new.
6. Screenshot copy per language (6 screens) in the same folder.

## Verify
Run app in each language via scheme options; check truncation in widgets (small family) and buttons; screenshots in each locale look correct.
