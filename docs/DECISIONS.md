# Decisions

Running log of implementation decisions not covered by the spec. Newest at the bottom.

## 2026-09-05

- Xcode project is generated from `project.yml` via XcodeGen so that project structure lives in a reviewable text file. Regenerate with `xcodegen generate` after editing `project.yml`.
- `CorbieCore` declares `.macOS(.v14)` alongside `.iOS(.v17)` so that the package builds and tests with `swift build` / `swift test` on a Mac without Xcode. UIKit-only code is guarded with `#if canImport(UIKit)`.
- The spec's `Task` entity is named `TaskItem`, `List` is `ChecklistList`, to avoid clashing with Swift standard library types.
- Tests use Swift Testing. Command Line Tools include neither XCTest nor Testing, so `scripts/test_core.sh` adds `swift-testing` 6.1.3 as an opt-in dependency through `CORBIE_EXTERNAL_TESTING=1` (6.2+ needs `_TestingInterop`, which the CLT toolchain lacks). Xcode ignores the flag and uses its bundled Testing.
- Core Data model is built programmatically (`NSManagedObjectModel` in code) instead of `.xcdatamodeld`, because `momc` is not available outside Xcode and a code model is diffable and unit-testable against the CloudKit rules (optional/default attributes, no unique constraints, no ordered relationships, inverses everywhere).
