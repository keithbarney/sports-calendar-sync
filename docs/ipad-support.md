# Native iPad support

Verified September 10, 2026 using local source at `9c5d8aa821a554534978ada6e87ababeddb55d31` plus the uncommitted workspace changes. No App Store upload or version bump was performed.

## Saved device and build

- Reuse **Sports Sync — iPad**, iPad Air 13-inch (M4), iOS 26.5, UDID `017B5198-4197-412E-8FAD-66E1B817324C` across tasks and worktrees. This was an existing simulator assigned to the app; no per-task device is needed.
- Installed Debug simulator app: **1.1.0 (3)**, bundle `com.keithbarney.sportssync`; compiled `UIDeviceFamily` is `[1, 2]`.
- Native tabs adapt to an iPad sidebar/top bar; iPhone retains system tabs. Lists preserve sidebar safe areas and limit excess width in wide windows.
- App supports portrait and landscape on iPad. Do not assume window resizing, Stage Manager, hardware keyboard, or physical-iPad behavior has been exhaustively tested.

```sh
xcodegen generate
xcodebuild -project SportsCalendarSync.xcodeproj -scheme SportsCalendarSync \
  -configuration Debug -destination 'platform=iOS Simulator,id=017B5198-4197-412E-8FAD-66E1B817324C' \
  -derivedDataPath /tmp/sports-calendar-sync-ipad-build build
xcrun simctl install 017B5198-4197-412E-8FAD-66E1B817324C /tmp/sports-calendar-sync-ipad-build/Build/Products/Debug-iphonesimulator/SportsCalendarSync.app
xcrun simctl launch 017B5198-4197-412E-8FAD-66E1B817324C com.keithbarney.sportssync -mock-data
```

Reuse the device even when shut down, and coordinate access before installing or navigating. Keep build output separate from other tasks.

## Verification

- 32 XCTest tests passed on the saved iPad. App and widget extension built successfully.
- Installed Simulator walkthrough: Following, team details, Manage Competitions sheet and dismissal, Discover, Settings and appearance selection. Fixed the review header covering the native top tab bar.
- Verified native portrait/landscape layouts, sidebar navigation, and Light/Dark appearance. Rebuilt and rechecked sidebar spacing after preserving the system safe area.
- Review runs use isolated mock data, with the review header intentionally visible. Normal production data and external services were not used for these checks.
- Build/test evidence for this local run is under `/tmp/sports-calendar-sync-ipad-*`. Temporary review images are not App Store screenshot deliverables.

- iPhone smoke check on the same universal Debug artifact: Sports Sync Screenshot 1.1.0 (`B8CD88B2-D876-49ED-8CB8-303A0C59FEC5`): populated Following layout and native bottom tabs visually checked.

## Screenshot handoff

Use the core inventory in `AGENTS.md`, native device layouts, stable filenames and the four canonical device/appearance folders. This implementation does not refresh the maintained App Store screenshot matrix. Use an explicit mock capture mode that hides review controls, verify actual appearance and native dimensions, and replace matching files only after validation. Never reuse a padded iPhone image as native iPad evidence.

The saved Sports iPad was shut down after review to recover from a macOS process limit. Boot the same UDID for the next run; the simulator and app data were retained.
