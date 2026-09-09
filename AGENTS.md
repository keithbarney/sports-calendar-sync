# Repository Guidelines

## Project Structure & Module Organization

- `SportsCalendarSync/` contains the SwiftUI app. Keep domain models in `Models/`, integrations and persistence in `Services/`, and screens/components in `Views/`.
- `SportsCalendarSyncWidget/` contains the WidgetKit extension and its shared model inputs.
- `SportsCalendarSyncTests/` contains XCTest unit tests for decoding, fixture reconciliation, refresh policy, health reporting, and background scheduling.
- `SportsCalendarSync/Assets.xcassets/` holds app icons and UI assets. Entitlements, privacy declarations, and property lists live beside their respective targets.
- `project.yml` is the XcodeGen source of truth; `SportsCalendarSync.xcodeproj` is generated. Release helpers are in `scripts/`, release notes in `docs/`, and App Store screenshots in `fastlane/`.

## Build, Test, and Development Commands

- `xcodegen generate` regenerates the Xcode project after changing `project.yml` or adding target source files.
- `xcodebuild -project SportsCalendarSync.xcodeproj -scheme SportsCalendarSync -destination 'platform=iOS Simulator,name=iPhone 16' test` builds and runs the XCTest suite on Simulator.
- `./scripts/release.sh verify` runs the same unsigned Release device build used by CI and checks that generated project changes are committed.
- `./scripts/release.sh archive` creates a signed archive; `./scripts/release.sh upload` uploads it to App Store Connect. Keep credentials and signing keys outside the repository.

## Coding Style & Naming Conventions

Prefer standard iOS and SwiftUI components, including Form, List, Section, Toggle, and system toolbar buttons. Use native styling and behavior instead of custom controls unless explicitly requested.

Use four-space indentation and the existing Swift formatting. Name types and views in `PascalCase`; use `camelCase` for properties, methods, and test names such as `testNewFixtureIsInserted`. Keep UI code in `Views/`, business/integration logic in `Services/`, and shared app/widget models compatible. Follow Swift concurrency conventions and isolate UI, SwiftData, and EventKit interactions appropriately. No formatter or linter is configured, so review formatting in Xcode and keep generated project files synchronized.

## Testing Guidelines

Tests use XCTest. Add focused `*Tests.swift` files under `SportsCalendarSyncTests/`, with `XCTestCase` classes and `test...` methods. Cover behavior changes, especially ESPN payload variations, postponed fixtures, calendar repair/idempotency, refresh scheduling, and permission/error paths. There is no stated coverage threshold; run the full suite before opening a pull request.

## Commit & Pull Request Guidelines

Recent commits use short, imperative, Conventional Commit-style prefixes such as `fix:` and `build:`. Keep commits focused and describe the user-visible or technical outcome. Pull requests should include a concise summary, tests and simulator/device versions used, screenshots for UI or widget changes, and notes about project, entitlement, privacy, or release configuration changes. Never commit API keys, signing credentials, provisioning profiles, or private calendar data.
