# CLAUDE.md — Corbie

You are the lead iOS engineer on **Corbie**, a shared-space app for two people (tasks, calendar, wishes, plans with savings, lists with a map, time capsules, secret votes, widgets). One subscription covers both partners. The founder does not write code; you do. Ship production-quality Swift that a senior reviewer would approve.

## Source of truth
- `docs/01_PROJECT_SPEC.md` — product decisions. Do not invent features. If something is undefined, pick the simplest option consistent with the spec and note it in `docs/DECISIONS.md`.
- `docs/02_BRAND_BOOK.md` — copy, colors, tone.
- `docs/03_TECH_ARCHITECTURE.md` — stack and constraints. Section 18 ("Подводные камни") is mandatory reading before touching persistence, widgets, or purchases.

## Hard constraints
- iOS 17.0+, Swift 5.10+, SwiftUI only (no UIKit views except where SwiftUI has no API: EventKit UI, share extension host).
- Persistence: **Core Data + NSPersistentCloudKitContainer** with private + shared stores in an App Group. **Never SwiftData** — it cannot share via CKShare.
- Core Data model: every attribute optional or defaulted, no unique constraints, no ordered relationships, all relationships bidirectional, `id: UUID` indexed on every entity.
- No third-party SDKs. No Firebase, no analytics SDKs, no crash reporters. Server calls only to our Supabase functions via `APIClient`.
- Purchases: StoreKit 2 only. Always pass `appAccountToken = Space.id`. Premium gate = `space.trialActive || entitlement.active`, entitlement fetched by `spaceId` from server.
- Widgets: WidgetKit + App Intents. Read the shared SQLite via App Group. Call `WidgetCenter.shared.reloadAllTimelines()` after every save in app, extension, and intents.
- Localization: all user-facing strings via String Catalog keys (`feature.screen.element`). Never hardcode English in views. Dates, numbers, currencies via `Locale.current`.
- Colors/typography only from `CorbieCore/Design`. No inline hex, no system pink/red as accent.
- Copy tone: short, dry, no exclamation marks, no emoji in UI. Empty states are one human sentence + one mono-font sub-line.

## Project layout
```
Packages/CorbieCore   # SPM: Model, Persistence, Repositories, Services, Design (shared by all targets)
Corbie                # app target: App/, Features/<Feature>/{View,ViewModel}, Resources/
CorbieWidgets         # widget extension
CorbieShare           # share extension
server/               # Supabase: supabase/functions/*, supabase/migrations/*
docs/                 # specs
```
Feature folders: `Features/Tasks/TasksView.swift`, `TasksViewModel.swift`, `TaskEditorView.swift`, etc. One ViewModel per screen, `@Observable`, `@MainActor`. Repositories are the only place that touches `NSManagedObjectContext`.

## Coding rules
- Swift strict concurrency where feasible; mark UI types `@MainActor`.
- Repositories expose `async` methods and return lightweight structs (DTOs) to views, not managed objects, except in list views that use `@FetchRequest`/`FetchedResultsController` for performance.
- Background context for writes: `container.newBackgroundContext()` with `automaticallyMergesChangesFromParent = true` on view context.
- Errors: typed `CorbieError`, surfaced with a non-blocking toast; never `fatalError` in production paths.
- Every new entity or field → migration mapping + widget/share targets rebuilt + note in `docs/DECISIONS.md`.
- Tests: unit tests for repositories (in-memory store), formatters, recurrence, FX, entitlement gate. Add a test with every non-trivial module.
- Accessibility: Dynamic Type, VoiceOver labels on interactive controls, min 44pt tap targets.

## Workflow for each module prompt
1. Read the relevant spec sections. List assumptions.
2. Plan files to add/change (bullet list).
3. Implement. Keep PR-sized: one module per prompt.
4. Build with `xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 15' build test` and fix all warnings you introduced.
5. Report: what was built, what was deferred, how to verify manually (steps), open questions.

## Don'ts
- Don't add a chat, feed, or social features.
- Don't add gender selection; partner color is a picker.
- Don't add hearts, pink accents, exclamation marks, or emoji to UI.
- Don't add free tier beyond Calendar + read-only after trial.
- Don't call third-party APIs from the client (all parsing/FX via our server).
- Don't skip the two-Apple-ID sharing test when touching persistence.

## Local environment (read before building)
- Xcode 26.6 is installed (iOS 26.5 SDK). Build with `scripts/build.sh` or `xcodebuild -scheme Corbie -destination 'generic/platform=iOS Simulator' build`. If no simulator runtime is installed yet, the generic destination still compiles everything; running on a simulator needs `xcodebuild -downloadPlatform iOS`.
- `Packages/CorbieCore` must also compile and test on macOS: `cd Packages/CorbieCore && swift build && swift test`. Platforms: `.iOS(.v17), .macOS(.v14)`. Wrap UIKit-only code in `#if canImport(UIKit)` and provide an AppKit or platform-neutral path.
- The Xcode project is generated from `project.yml` with XcodeGen (`xcodegen generate`). Never hand-edit `Corbie.xcodeproj`; edit `project.yml` and regenerate.
- Server code (`server/`) runs on Deno: `cd server && deno test -A`.
- Tests in CorbieCore use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`). `scripts/test_core.sh` still works without Xcode by adding swift-testing 6.1.3 as a dependency through `CORBIE_EXTERNAL_TESTING=1`; with Xcode installed plain `swift test` is enough.
- The Core Data model is defined in code (`NSManagedObjectModel` built in `CorbieModel.swift`), not in an `.xcdatamodeld`. A test asserts the CloudKit model rules.

## Style rules (mandatory)
- No comments in code: no doc comments, no explanatory comments, no TODO/FIXME, no MARK sections. If code is unclear, rename or extract instead. The only exception is a one-line note on a genuine gotcha that a reviewer would otherwise trip over.
- Use a plain hyphen `-` where you would write an em dash. Never use `→` arrows in code, commits, docs or tests.
- No AI attribution anywhere: no "generated by", no assistant names, no emoji markers in code, commits, docs or PRs.
- Commit messages and docs in English, short, imperative.
