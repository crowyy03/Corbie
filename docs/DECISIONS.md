# Decisions

Running log of implementation decisions not covered by the spec. Newest at the bottom.

## 2026-09-05

- Xcode project is generated from `project.yml` via XcodeGen so that project structure lives in a reviewable text file. Regenerate with `xcodegen generate` after editing `project.yml`.
- `CorbieCore` declares `.macOS(.v14)` alongside `.iOS(.v17)` so that the package builds and tests with `swift build` / `swift test` on a Mac without Xcode. UIKit-only code is guarded with `#if canImport(UIKit)`.
- The spec's `Task` entity is named `TaskItem`, `List` is `ChecklistList`, to avoid clashing with Swift standard library types.
- Tests use Swift Testing. Command Line Tools include neither XCTest nor Testing, so `scripts/test_core.sh` adds `swift-testing` 6.1.3 as an opt-in dependency through `CORBIE_EXTERNAL_TESTING=1` (6.2+ needs `_TestingInterop`, which the CLT toolchain lacks). Xcode ignores the flag and uses its bundled Testing.
- Core Data model is built programmatically (`NSManagedObjectModel` in code) instead of `.xcdatamodeld`, because `momc` is not available outside Xcode and a code model is diffable and unit-testable against the CloudKit rules (optional/default attributes, no unique constraints, no ordered relationships, inverses everywhere).
- Module 00: the Xcode project is generated into the repository root and committed, so the founder can open it without XcodeGen installed. `project.yml` stays the source of truth; `Configs/` holds the per-target entitlements and the Info.plist files XcodeGen writes.
- Module 00: XcodeGen 2.46 cannot put a Swift package test target into a scheme ("Spec validation error: Scheme "Corbie" has invalid test target "CorbieCoreTests""). The Corbie scheme therefore tests `CorbieTests` and `CorbieUITests`; `CorbieCoreTests` runs through `scripts/test_core.sh`.
- Module 00: one string catalog, `Corbie/Resources/Localizable.xcstrings`, is compiled into the app, the widget and the share extension, so a key resolves the same way in all three bundles.
- Module 00: the tab skeleton uses stock SwiftUI styling. It moves to `CorbieCore/Design` tokens and components once Module 01 lands.
- Module 00: `NSUserNotificationsUsageDescription` is in the app Info.plist because the module prompt asks for it; iOS does not read that key, the notification permission prompt has no usage string.
