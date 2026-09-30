# Sports Sync App Store screenshot capture

## Current six-benefit selection

Use the ordered core table in `AGENTS.md`: Calendar (11), Team details (2), Broadcasts (10), Reminder (7), Following (1), Appearance comparison (8). Keith approved the iPhone Light design on September 13, 2026, then requested iPhone Dark and iPad Light/Dark. Preserve the approved iPhone Light images and their actual source provenance during that extension. The older five-card/nine-screen inventories are not the default capture selection.

All final cards use the white/SF marketing template. Canonical output is `screenshots/<iphone|ipad>/<light|dark>/<number>-<device>-<appearance>-<slug>.png`; replace validated matching files. Keep one contact sheet, validation report and shared manifest at the screenshot root. No dated export folders or duplicate upload sets. Do not upload or submit unless asked.

## Saved devices and build

| Category | Saved simulator | Exact UDID | Native portrait pixels |
| --- | --- | --- | --- |
| iPhone | Sports Sync Screenshot 1.1.0, iPhone 17 Pro Max, iOS 26.5 | B8CD88B2-D876-49ED-8CB8-303A0C59FEC5 | 1320 × 2868 |
| iPad | Sports Sync — iPad, iPad Air 13-inch (M4), iOS 26.5 | 017B5198-4197-412E-8FAD-66E1B817324C | 2048 × 2732 |

Reuse these devices without erasing/uninstalling. Native universal support is enabled. Specifications were checked September 30, 2026 for 1.1.4. Current Debug capture app: `com.keithbarney.sportssync.local`, version 1.1.4 (1790809115); record actual installed artifact and source fingerprint for each run. No TestFlight.

## Native app capture

```sh
./scripts/capture-screenshots.sh --variants iphone/dark,ipad/light,ipad/dark --screens following,team-detail,broadcasts,reminder --output-root /tmp/sports-native
```

For all variants omit `--variants`. For a correction select exact combinations and `--screens`. `--devices`/`--appearances` are also supported. Default native app sources are the four routes above; Calendar is a separate system app source and Appearance is composed from the two Following sources.

The helper builds once through `SportsCalendarSyncScreenshots`, uses the exact saved simulators sequentially, runs `CaptureTests.testCaptureCoreScreens`, exports selected attachments, validates native dimensions and writes exact result-bundle/attachment/timestamp provenance. It stores native sources and test evidence in temporary directories, never over canonical marketing cards. It clears status-bar overrides when finished.

Tests navigate actual Following → Team details, scroll Broadcasts, and a separate Settings launch → Reminder. They assert representative mock content and hidden review controls. Returning through Simulator Home before launch clears cross-app breadcrumbs. The broadcast route uses the first fixture's actual position and a slow controlled drag to frame a complete row below navigation on both device categories; avoid an uncontrolled swipe that overscrolls long schedules.

## App-owned mock fixtures

Use `-screenshot-fixtures`, English, standard text size, and explicit `-appearanceMode Light|Dark`; `-screenshot-date <ISO8601>` sets the reference date. Normal mock UX review uses `-mock-data` and retains its header/picker. Never use the old live `-seed-data` option for screenshots.

The shared isolated dataset contains six followed clubs across their competitions and 23 verified bundled crests. Upcoming games have venues and representative US demo listings (NBC/Peacock, ESPN+, Paramount+, MLS Season Pass). Listings are fictional examples, not verified broadcasts for the depicted dates. Later Premier League fixtures extend the native iPad list enough to frame the Broadcasts section. The approved iPhone Light source retains its original five-fixture schedule; the new variants use the expanded schedule with the same initial fixture dates/clubs. Externals remain blocked at service boundaries: ESPN, real calendar/notification writes, purchases and personal stores are not used.

`ScreenshotFixturesTests` verifies isolated stores/replay, all artwork, fixture provider routes and simulated external writes. Preserve provenance for reused images rather than claiming a new capture.

## Separate Apple Calendar demo

`scripts/SportsCalendarDemo.swift` is a standalone Simulator-only EventKit helper, outside the production target. It refuses non-local sources and stages four fictional matches in a local calendar named Sports, matching the app's event title, venue, broadcast notes and 30-minute reminder structure. The September 13 set depicts September 14: Manchester United–Arsenal at noon, Real Madrid–Barcelona at 2:30, Bayern–Dortmund at 5, LAFC–LA Galaxy at 7:30. This is a manually staged demonstration, not a test of app calendar sync.

Build/package the helper as a separate iOS Simulator app with `NSCalendarsFullAccessUsageDescription`, bundle `com.keithbarney.sports-marketing-demo`; install only on the exact saved Sports simulators. The supported simulator privacy service is `calendar`, not `calendar-full`. Verify its Documents/result.txt confirms local-only success before proceeding. Never weaken the main app's mock-write protections or use a personal device/calendar.

Open `com.apple.mobilecal` to the actual demo date using `calshow:<seconds since 2001-01-01 UTC>`. Dismiss first-launch notifications/location prompts. Return through Simulator Home and relaunch Calendar if a helper breadcrumb appears. iPhone uses the day timeline; iPad shows the same four matches alongside the selected event's calendar, reminder and broadcast notes. Explicitly set each appearance and verify the screen, then capture with `simctl io <saved UDID> screenshot`. Record the system source separately:

```sh
python3 scripts/register-calendar-captures.py --source-root /tmp/sports-native --variants iphone/dark,ipad/light,ipad/dark --fixture-date 2026-09-14 --helper-source /path/to/actual-compiled-helper.swift
```

## Compose, review and publish

Use Python with Pillow, such as Codex's bundled Python at `/Users/keithbarney/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`.

```sh
python3 scripts/compose-benefits.py --source-root /tmp/sports-native --variants iphone/dark,ipad/light,ipad/dark --stage /tmp/sports-review
```

`--variants` and `--screens` narrow composition. Native input hashes, provenance, device/appearance and dimensions must match. Composed cards cannot be reused as native captures. All appearance cards are composed from the matching device's fresh Light/Dark Following captures.

Geometry: iPhone 1320×2868, SF Semibold 124, title top 210/line 136, screen top 700/width 1100, frame 14/radius 108. iPad 2048×2732, SF 163, title top 159/line 179, screen top 645/width 1707, frame 22/radius 64. The iPad appearance pair uses screen width 1230, Light (165,724), Dark (653,1012), frame 16/radius 48, with matching outer margins. Dark is in front; no labels.

Inspect the contact sheets and originals for benefit content, headline fit, legibility, appearance, debug chrome and framing. Save `visual-review.json` in the stage with `passed: true` and a `hashes` dictionary keyed by every output path relative to the stage. Repeat the compose command with `--publish`. Publication requires those exact reviewed hashes and complete validated selected sets before mutation; it replaces matching cards, retires superseded selected-variant files/records, and preserves all untouched images/provenance. Current `compose-marketing.sh` is the legacy five-card composer; do not use it for the six-benefit selection.

## 1.1.4 capture refresh

All four device/appearance sets were refreshed September 30, 2026. The Calendar demo depicts October 1, 2026. `CaptureTests.testInspectSystemCalendarDemo` opens Calendar through its native Home icon, selects tomorrow, frames the four games on iPhone, and keeps the selected event details on iPad. A selected event toggles off when tapped again, so the route checks Edit before selecting it. Final settled system images use simctl captures after that route and visual inspection; their exact result bundles are in the manifest.

Successful captures were retained across a tab-navigation correction and an XCTest screenshot transport timeout. The iPhone Dark Broadcasts source uses a simctl capture after the native content assertions passed; its exact test run and native filename are recorded. The helper disables verbose failure diagnostics and touches only devices in the selected variant list. Canonical App Store upload selects the six Light cards for each device; Dark candidates remain maintained locally.
