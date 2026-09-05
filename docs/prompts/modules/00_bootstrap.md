# Module 00 — Bootstrap the project

Read `docs/01_PROJECT_SPEC.md` §5, §7 and `docs/03_TECH_ARCHITECTURE.md` §2, §15, §18 first.

## Goal
Create the Xcode workspace skeleton exactly as described in `03_TECH_ARCHITECTURE.md` §15, with all targets compiling and an empty tab bar running in the simulator.

## Do
1. Create `Corbie.xcodeproj` with targets: `Corbie` (iOS app), `CorbieWidgets` (widget extension), `CorbieShare` (share extension), `CorbieTests`, `CorbieUITests`. Deployment target iOS 17.0. Bundle IDs: `app.corbie`, `app.corbie.widgets`, `app.corbie.share`.
2. Create local SPM package `Packages/CorbieCore` with library target `CorbieCore` and test target. Link it to all three product targets.
3. Capabilities on app + widgets + share: iCloud (CloudKit, container `iCloud.app.corbie`), App Groups (`group.app.corbie`), Push Notifications (app only), Sign in with Apple (app only), Background Modes: remote-notification (app only).
4. Add `Info.plist` usage strings (placeholders, localized later): NSCalendarsFullAccessUsageDescription, NSPhotoLibraryUsageDescription, NSCameraUsageDescription, NSLocationWhenInUseUsageDescription, NSFaceIDUsageDescription.
5. App entry `CorbieApp.swift` with `AppState` (@Observable) and `RootView` showing a `TabView` with five tabs: Tasks, Calendar, Wishes, Plans, Us — each a placeholder view with the tab title. Add a top-trailing "Us" pill button (two circles) on each tab that opens an empty sheet.
6. Create `docs/DECISIONS.md` with a header and today's date.
7. Add `.gitignore` for Xcode, `README.md` with build instructions.
8. Set up `server/` with `supabase init` structure (functions folder empty, migrations folder empty).

## Verify
- `xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 15' build` succeeds with zero warnings.
- App launches, five tabs visible, Us pill opens a sheet.
- Widget and Share targets build (can be empty).

## Report
List created files, capability settings applied, and anything you could not do without an Apple developer account (note it, don't block).
