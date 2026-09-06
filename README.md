# Corbie

Corbie is an iOS app for two people: one shared space for tasks, calendar, wishes, plans with savings and prep steps, lists with a map, time capsules and votes.
One subscription covers both partners, and the everyday parts live in home screen and lock screen widgets.

## Requirements

- macOS 14 or newer
- Xcode 16 or newer (iOS 17.0 deployment target)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Deno 2 and the Supabase CLI for `server/`

## Generate the project

`project.yml` is the source of truth for the Xcode project. `Corbie.xcodeproj` is committed so the project opens
without extra steps, but never edit it by hand - change `project.yml` and regenerate:

```sh
xcodegen generate
```

## Build and test

```sh
xcodebuild -scheme Corbie -destination 'platform=iOS Simulator,name=iPhone 15' build test
```

`scripts/build.sh` wraps the same command (it regenerates the project first and accepts extra `xcodebuild` actions,
for example `scripts/build.sh build test`).

The `Corbie` scheme tests `CorbieTests` and `CorbieUITests`. `CorbieCoreTests` lives in the local package and
XcodeGen cannot put a package test target into a scheme, so it runs on its own - and it needs no Xcode, Command
Line Tools are enough:

```sh
scripts/test_core.sh
```

`scripts/check_strings.sh` fails when a view in `Corbie/`, `CorbieWidgets/` or `CorbieShare/` holds a hardcoded
user-facing literal instead of a String Catalog key, or when a hex color appears outside the design tokens.

## Server

```sh
cd server && supabase start
```

`server/API.md` is the request and response contract for the Supabase functions.

## Targets

| Target | Bundle id | Notes |
|---|---|---|
| Corbie | `app.corbie` | app, tab bar and features |
| CorbieWidgets | `app.corbie.widgets` | WidgetKit extension |
| CorbieShare | `app.corbie.share` | share extension for one link or one piece of text |
| CorbieTests | `app.corbie.tests` | unit tests hosted by the app |
| CorbieUITests | `app.corbie.uitests` | launch smoke test |

`Packages/CorbieCore` is a local Swift package linked into the app, the widgets and the share extension.

## What needs an Apple developer account

The project builds for the simulator as it is. These steps are blocked until the account exists, and each of them
has to be done once by the account holder:

- **Development team.** `DEVELOPMENT_TEAM` is empty in `project.yml`. Set it there (not in Xcode, or the next
  `xcodegen generate` drops it) and pick the team in Signing and Capabilities.
- **CloudKit container.** Create `iCloud.app.corbie` and, before release, push the schema from the CloudKit
  Dashboard development environment to production.
- **App Group.** Register `group.app.corbie` for the app, the widgets and the share extension.
- **Push and Sign in with Apple.** Enable both capabilities on the app id. `aps-environment` is `development` in
  `Configs/Corbie.entitlements`; the release build needs `production`.
- **Associated domains.** `applinks:corbie.app` needs an `apple-app-site-association` file served from
  `https://corbie.app/.well-known/`.
- **App Store Connect products.** `app.corbie.monthly` at 4.99 USD and `app.corbie.yearly` at 29.99 USD in one
  subscription group. `Products.storekit` mirrors them for local StoreKit testing.
- **App Store Server Notifications.** Separate sandbox and production URLs pointing at the Supabase function.
