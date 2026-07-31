# Repository Guidelines

## Project Structure

The SwiftUI app lives in `SportsCalendarSync/`; widget code is in `SportsCalendarSyncWidget/`; XcodeGen configuration is `project.yml`; and the generated project is `SportsCalendarSync.xcodeproj`. Fastlane and release scripts live in `fastlane/` and `scripts/`. Treat `project.yml` as the source of truth for targets and build settings, and read `CLAUDE.md` before broad changes.

## Development Commands

- `xcodegen generate` regenerates the Xcode project after configuration changes.
- `xcodebuild -project SportsCalendarSync.xcodeproj -scheme SportsCalendarSync -destination 'generic/platform=iOS Simulator' build` builds for Simulator.
- Open the project in Xcode for signing, widget previews, and device testing.

Use the existing helper scripts only after reading them; some install, sign, or target physical devices.

## Style, Testing, and Changes

Use four-space indentation, `PascalCase` types, `camelCase` properties/functions, and Swift concurrency conventions. Keep shared app/widget models compatible and avoid network or calendar access on the main actor. No test target is currently declared, so require a clean build plus manual checks for permissions, syncing, widgets, offline behavior, and seeded-data mode.

Use focused imperative commits. Pull requests should list devices and OS versions tested, flag entitlement or project changes, and include screenshots for UI/widget work. Never commit signing credentials, API secrets, provisioning profiles, or private calendar data.
