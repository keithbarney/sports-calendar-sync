# Repository Guidelines

## Project Structure & Module Organization

- `SportsCalendarSync/` contains the SwiftUI app. Keep domain models in `Models/`, integrations and persistence in `Services/`, and screens/components in `Views/`.
- `SportsCalendarSyncWidget/` contains the WidgetKit extension and its shared model inputs.
- `SportsCalendarSyncTests/` contains XCTest unit tests for decoding, fixture reconciliation, refresh policy, health reporting, and background scheduling.
- `SportsCalendarSync/Assets.xcassets/` holds app icons and UI assets. Entitlements, privacy declarations, and property lists live beside their respective targets.
- `project.yml` is the XcodeGen source of truth; `SportsCalendarSync.xcodeproj` is generated. Release helpers are in `scripts/`, release notes in `docs/`, and screenshots in `screenshots/`.

## Build, Test, and Development Commands

- Use GPT-5.6 Luna for routine new-build creation and phone delivery, as Keith requested. Escalate complex build or signing failures to a stronger model when needed.
- `xcodegen generate` regenerates the Xcode project after changing `project.yml` or adding target source files.
- `xcodebuild -project SportsCalendarSync.xcodeproj -scheme SportsCalendarSync -destination 'platform=iOS Simulator,id=B8CD88B2-D876-49ED-8CB8-303A0C59FEC5' -derivedDataPath "$TASK_DERIVED_DATA" -parallel-testing-enabled NO test` runs XCTest on the project-owned iPhone listed in `docs/capture-plan.md`. Before running, set `TASK_DERIVED_DATA` to a task-specific output directory and confirm the saved destination is available; use a different directory for each concurrent task.
- `./scripts/release.sh verify` checks release configuration and generates an unsigned Release device build; it does not run XCTest or require a clean checkout. Signed archive creation separately requires a clean worktree.
- `./scripts/release.sh archive` creates a signed archive; `./scripts/release.sh upload` uploads it to App Store Connect. Keep credentials and signing keys outside the repository.

## Sync architecture and verification boundaries

- Trace fixture updates through `Services/ESPNService.swift`, `TeamManager.swift`, `StoreService.swift`, and `CalendarService.swift`; refresh policy and health are in `AutomaticRefreshService.swift`, `SyncModels.swift`, and `SyncHealthStore.swift`. Preserve fixture identity and idempotent calendar repair across postponements, reschedules, time zones, and repeat refreshes.
- Debug bundle `com.keithbarney.sportssync.local` uses `Sports (L)`; Release uses `Sports`. A separate calendar name alone does not prove all saved event identifiers are isolated. Inspect reuse/update/delete paths before exercising calendar writes, and preserve production events. `(L)` is a development distinction, not a guarantee of device-only storage.
- For crash work, correlate the exact app version/build and symbolicated stack with the affected path; distinguish crash events from unique users. A newer submitted build is not evidence that a reported crash was fixed.
- Use `docs/RELEASE.md`, version-specific release notes/receipts, and `docs/app-store-search-experiment.md` for release context. Reconcile dated documents with `project.yml` and current verified App Store state before editing metadata; do not combine an experiment with unrelated unvalidated checkout changes. Shared delivery guidance supersedes stale TestFlight references.
- Handoff records the configuration, bundle, exact Simulator/device and tested journey, failures/skips, and delivered artifact if any. Keep build, calendar-sync verification, phone installation, upload, review and public release as distinct outcomes.

## Coding Style & Naming Conventions

Prefer standard iOS and SwiftUI components, including Form, List, Section, Toggle, and system toolbar buttons. Use native styling and behavior instead of custom controls unless explicitly requested.

Use four-space indentation and the existing Swift formatting. Name types and views in `PascalCase`; use `camelCase` for properties, methods, and test names such as `testNewFixtureIsInserted`. Keep UI code in `Views/`, business/integration logic in `Services/`, and shared app/widget models compatible. Follow Swift concurrency conventions and isolate UI, SwiftData, and EventKit interactions appropriately. No formatter or linter is configured, so review formatting in Xcode and keep generated project files synchronized.

## Testing Guidelines

Tests use XCTest. Add focused `*Tests.swift` files under `SportsCalendarSyncTests/`, with `XCTestCase` classes and `test...` methods. Cover behavior changes, especially ESPN payload variations, postponed fixtures, calendar repair/idempotency, refresh scheduling, and permission/error paths. There is no stated coverage threshold; run the full suite before opening a pull request.

## Commit & Pull Request Guidelines

Recent commits use short, imperative, Conventional Commit-style prefixes such as `fix:` and `build:`. Keep commits focused and describe the user-visible or technical outcome. Pull requests should include a concise summary, tests and simulator/device versions used, screenshots for UI or widget changes, and notes about project, entitlement, privacy, or release configuration changes. Never commit API keys, signing credentials, provisioning profiles, or private calendar data.

## Core screens for screenshots

The September 13 benefit-led selection replaces the previous five-card inventory. Default refresh coverage remains iPhone/iPad × Light/Dark unless Keith limits the request. Keith approved the September 13 iPhone Light set and requested the remaining three variants. Preserve the approved iPhone Light PNGs and provenance while extending the same six benefits to iPhone Dark and iPad Light/Dark.

Use the approved white/SF template, standard text size, and real native app captures with `-screenshot-fixtures`. Fixtures remain in memory with external writes blocked; no mock header or picker may appear. Stable file IDs are independent of presentation order.

| Order | Stable ID / slug | Benefit headline (maximum two lines) | Supporting native content |
| --- | --- | --- | --- |
| 1 | 11 / `calendar` | Sync matches<br>to your calendar. | Apple Calendar day view with several fictional fixtures in the saved Sports simulator's **local-only** Sports calendar. This separate, explicitly authorized demo is manually staged, not evidence of app sync. |
| 2 | 2 / `team-detail` | Your teams.<br>All their competitions. | Club identity, followed competition count, and upcoming league/cup fixtures. Supported competitions only. |
| 3 | 10 / `broadcasts` | Know where<br>to watch. | Scroll native Team Details until the club artwork clears the navigation bar and fixture/channel listings are visible. Use representative US demo listings; actual provider coverage varies. |
| 4 | 7 / `reminder` | Get reminders<br>before kickoff. | Settings → Reminder; show the real 15 minute, 30 minute, one hour, day-before and Off choices. |
| 5 | 1 / `following` | All your favorites<br>in one place. | Several followed clubs with correct bundled crests and competition labels. |
| 6 | 8 / `appearance` | Light or dark.<br>Make it yours. | Overlapping native Following captures; Dark in front, no labels, outer margins matching the single-screen cards. ID 8 now depicts the appearance comparison, not the old picker capture. |

Discover and search are excluded from the marketing inventory. Manage Competitions remains a useful navigation/test route but is not a separate card in this selection. Exclude accessibility/large text, errors, empty states, developer controls, system permission prompts and widgets unless requested. Preserve untouched device/appearance variants and their provenance when reviewing only iPhone Light.

## Core benefits and marketing screenshots

Lead with calendar sync, followed by competition coverage, broadcast information, reminders, followed teams and appearance. Do not promise every sport, universal broadcast coverage, instant schedule updates or guaranteed attendance. App calendar events are named Sports and include fixture names, venue, competition and available broadcast notes.

The native capture helper accepts `--devices`, `--appearances`, and `--screens`, including `broadcasts` and `reminder`. Use `scripts/compose-benefits.py --variants iphone/light,iphone/dark,ipad/light,ipad/dark` for the six-card selection; see `docs/capture-plan.md`. Its Calendar source and Light/Dark comparison inputs require separate provenance. The older `compose-marketing.sh` is a legacy five-card workflow; use the benefit composer for current store sets.

## Mock Data and Screenshot Capture

Use `/Users/keithbarney/Documents/Github/sports-calendar-sync/screenshots` from every checkout/worktree, with `<iphone|ipad>/<light|dark>/<number>-<device>-<appearance>-<screen-name>.png`. Replace validated matching captures in place. Keep manifest/validation metadata in the root and no dated folders or duplicate upload sets. Follow `/Users/keithbarney/Documents/Github/AGENTS.md` and `screenshots/README.md`. Existing iPad-sized legacy images are padded iPhone layouts, not proof of native iPad support.

Use the reusable Debug fixtures in `Services/ScreenshotFixtures.swift`: `-mock-data` shows the native review header; `-screenshot-fixtures` uses the same isolated dataset with review controls hidden. See `docs/capture-plan.md` for the saved simulators, selected-screen native UI test, and `scripts/capture-screenshots.sh` command. Keep fixtures and capture routes current when changing screens. Screenshot mode must never use live ESPN starter data or personal stores.

## iPad development simulator

Reuse iPad Air 13-inch (M4) on iOS 26.5, UDID `017B5198-4197-412E-8FAD-66E1B817324C`, for this app’s iPad development and review across tasks/worktrees. This existing device was assigned to the project on September 10, 2026. Use isolated opt-in mock data; do not erase it or create another task-specific iPad. Native universal Debug builds were installed and reviewed on September 10, 2026, including portrait/landscape, adaptive tabs/sidebar, main screens, and Light/Dark appearance. See `docs/ipad-support.md` for build and review evidence. Capture and validate the core screenshot matrix separately before declaring screenshot delivery complete.

## Feedback and user research

Maintain parity with TV & Movie's categorized feedback and optional saved three-question survey. See `docs/feedback.md` for entry points, privacy/consent behavior, local invitation timing, mock isolation, and native test routes. Feedback forms and surveys remain excluded from the core marketing screenshot inventory unless explicitly requested.
