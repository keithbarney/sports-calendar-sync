# Upcoming Matches widget

Small shows one upcoming match, medium shows up to two, and large shows up to four upcoming matches across all followed teams and competitions, sorted by kickoff. The same match appears once when both opponents are followed. The newest duplicate's status wins; finished, postponed, canceled, abandoned, suspended, delayed, and in-progress fixtures are excluded. All dates use the device locale and time zone. Tapping opens Following and clears the current competition filter.

## Data and persistence

The app publishes a small atomic JSON snapshot to the shared App Group `group.com.keithbarney.sportssync`. The extension reads this snapshot rather than opening its own SwiftData database. Publishing occurs on launch and after follow changes or saved fixture syncs, and requests a WidgetKit timeline reload when the snapshot changes. Timelines advance at kickoff; an hourly refresh is requested subject to iOS scheduling.

Adding the App Group must not move the app's existing data. `SportsCalendarSyncApp` explicitly uses `groupContainer: .none` for its existing SwiftData configuration. Both app and extension need the App Group entitlement and matching provisioning profiles. Project configuration lives in `project.yml`.

## Simulator review

Use the saved Sports simulator with Debug arguments `-mock-data -mock-widget-review`. Optionally add `-mock-second-divisions`. This explicitly writes only `review-upcoming-fixtures.json`, separate from the production snapshot. Only Simulator Debug extensions read that file and show **Mock data** in the widget header. Normal launches remove the review snapshot and republish real app data. All other mock launches skip widget writes, and phone builds cannot publish or read the Simulator review snapshot.

The widget uses native system colors and explicit sixteen-point content padding in all sizes. References inspected: [FotMob's compact upcoming-match widgets](https://mobbin.com/screens/68103f32-f478-475f-a76d-0946917d7a97) and [Apple Sports' widget size variations](https://mobbin.com/screens/cd3f1193-d220-48a3-89e6-0201c67e3490). The implementation uses a chronological list with prominent crests and competition labels.

The small widget pairs the two crests above kickoff/date and competition; visible team names, location and network are omitted. Medium shows two matches and large shows four, both with crests only. No widget size displays team names. Medium and large place the home team on the left and away team on the right, with centered metadata in the approved order: time, day/date, stadium, competition, network. Time uses the primary text color; other metadata uses the same secondary gray with consistent half-point metadata spacing. Large adds two points of vertical padding on each side of its dividers. Medium omits the network line. Large uses 37.8-point crests and 16-point kickoff text; medium uses 37.8-point crests and 14-point kickoff text. Small uses 43.2-point crests and 14-point kickoff text. All sizes use nine-point secondary metadata. Team names remain in every fixture’s accessibility label. AM/PM stays smaller, and dates/times respect the device locale. Blank metadata is omitted, repeated network names are combined, and long metadata truncates while remaining complete in the accessibility label. Shared `WidgetContentView` renders all three sizes. Add `-widget-design-review` to the mock launch arguments for a native renderer preview; this is separate from a live Home Screen widget.

The app caches 96-pixel PNG crests in the App Group and asks WidgetKit to reload when artwork arrives. The extension reads local images synchronously, with club initials if artwork is unavailable. Production downloads accept HTTPS ESPN CDN references only. Simulator review uses bundled artwork in a separate `review-crests` directory. Optional logo fields preserve compatibility with snapshots saved before the redesign.

Widget crests render directly on the widget surface in every size, without circular backgrounds or extra image padding. The initials fallback also has no surrounding container.

Unit tests cover follow scoping, duplicate reconciliation, excluded statuses, kickoff transitions, snapshot coding, and removal of retained-but-unfollowed history. Live Home Screen review and phone installation evidence are recorded in the task handoff.

## September 14 verification

- Final unit suite: 39 tests passed on the saved Sports iPad (iOS 26.5), `/tmp/sports-final-unit.xcresult`.
- Signed Debug app and extension built successfully for Keith's iPhone 16 Pro (iOS 27.0 beta): version 1.1.1 (3), bundle `com.keithbarney.sportssync`, source `9c5d8aa` plus the existing working tree and this task's changes.
- The app executable SHA-256 for this installation is `558fad803849714d32e0c2b8e85551f8df03af71a31d820eed624f6332bacf78`.
- Installed on the phone successfully. Device installation records and final build logs are in `/tmp/sports-phone-install.json` and `/tmp/sports-phone-final-build.log`.
- iPad UI automation reached competition save/reopen, but its final navigation check was interrupted. SpringBoard's crash report identifies the saved iPad and an `XCTAutomationSupport` accessibility-session stack (`SpringBoard-2026-09-14-160356.ips`); this is not a successful full UI test run.
- Direct iPhone review verified Darmstadt's real bundled crest, league/cup fixture display, selecting all five mock competitions, and the resulting five followed competitions/fixtures.
- The redesigned widget passed 40 unit tests (`/tmp/sports-widget-design-unit.xcresult`), including logo snapshot compatibility. Native renderer review confirmed real bundled crests and readable layouts in all sizes. XCTest opened the actual Home Screen app menu and confirmed Small widget, Medium-sized widget, and Large widget controls. Full live resizing/tap-through verification is being tracked separately from this menu evidence.
- Redesign delivery: signed Debug **1.1.1 (4)**, app and widget extension, installed and launched normally on Keith's iPhone 16 Pro. Device app records confirmed version/build. Source remains `9c5d8aa` plus the existing working tree and this task's changes. App executable SHA-256: `4aa55098358f20b0319062225c154962e85f69a11ac333cc8d84e7d9a9641df0`. Evidence: `/tmp/sports-widget-phone-final.log`, `/tmp/sports-widget-phone-install-final.json`, `/tmp/sports-widget-phone-launch-final.json`, `/tmp/sports-widget-phone-apps.json`.
- Follow-up crest correction: ESPN scoreboards provide `team.logo`, while schedules/directories provide `team.logos`. The decoder now supports both through `crestURL`, and fixture reconciliation saves the real URLs. Production Swift decoding verified all 22 competitors in 11 real upcoming fixtures. A one-time foreground refresh after upgrading repairs existing fixtures before the usual six-hour refresh interval; subsequent automatic refreshes retain their normal throttle.
- Crest correction delivered as signed Debug **1.1.1 (5)**, installed and launched normally; device records confirmed version/build. App executable SHA-256: `7c1fd6b390a6de396744e9682bad9afc3c0ed74486fc29b0861e984bbab1b4da`. Evidence: `/tmp/sports-widget-crests-final-build.log`, `/tmp/sports-widget-crests-final-install.json`, `/tmp/sports-widget-crests-final-launch.json`, `/tmp/sports-widget-crests-final-apps.json`. Direct phone snapshot inspection was unavailable because CoreDevice rejected the App Group file transfer; phone Home Screen appearance is not claimed as visually verified.
- Final verification: 42 unit tests passed (`/tmp/sports-widget-crests-unit.xcresult`). The real Home Screen widget was resized through small, medium, and large and tapped into Following successfully on the saved Sports iPhone simulator (`/tmp/sports-widget-resize-verified.xcresult`). All sizes displayed the expected fixtures and bundled crests, including six fixtures on large. Light/dark native renderer review also passed; screenshots were inspected (`/tmp/sports-widget-sizes-attachments`). Live Home Screen captures are in `/tmp/sports-widget-resize-attachments`. All simulator visual checks used explicitly marked, isolated mock data; real ESPN decoding was verified separately.

## Venue and broadcast spacing update

The app projects existing fixture venue and broadcast data into optional snapshot fields, preserving compatibility with older saved snapshots. Both sizes show venue in the center column; large also shows a separate network line, while medium omits networks. Full available details are included in the accessibility label even when a visible label truncates. Broadcaster availability follows the same provider data as the app.

[FotMob venue and TV details](https://mobbin.com/screens/b9e862bd-e136-4f9e-9231-13e0ebe35d7d) informed the secondary location/TV icon rows beneath the matchup.

## Following tab

Each club now shows its next opponent (home or away), kickoff and competition from locally saved fixtures. It considers all competitions that club follows, even when the competition filter narrows which clubs are listed. Started, finished, postponed and canceled matches are excluded; duplicate statuses are reconciled before selecting the earliest fixture. The view advances its time every minute and shows “No upcoming fixtures” when none qualify.

Native Following review passed on the saved Sports iPhone simulator: populated Light/Dark, team details and back, competition filtering, and a past-date mock fixture scenario. Evidence: `/tmp/sports-following-next-review.xcresult` and `/tmp/sports-following-next-attachments`.

Combined delivery: signed Debug **1.1.1 (6)**, app and widget, installed and launched on Keith's iPhone 16 Pro. Device records confirmed the version/build. Source is `9c5d8aa` plus the existing working tree and these changes. App executable SHA-256: `521e56d1fec4c0f564420c160336cf0dd4aea0af7ca74da304000d84ac0f379d`. Build/install/launch evidence: `/tmp/sports-widget-following-phone-build.log`, `/tmp/sports-widget-following-phone-install.json`, `/tmp/sports-widget-following-phone-launch.json`, and `/tmp/sports-widget-following-phone-apps.json`.

The initial two-match medium/four-match large prototype was too crowded with the extra metadata and was reduced to one/three after native review. The final renderer passed Light/Dark review with long venue names (`/tmp/sports-widget-spacious-render.xcresult`, captures in `/tmp/sports-widget-spacious-render-attachments`).

## Approved centered layout

Keith approved the three-fixture concept after reviewing opposing team crests with centered metadata, uniform secondary gray, primary-colored kickoff text and three-point gaps. The initial implementation used this layout for medium (one match) and large (three matches); Keith subsequently requested the two/four capacity below. Small retains its compact stacked teams. References for the design exploration were [opposing crests](https://mobbin.com/screens/7dc77398-839f-48b2-8b12-29ac90b2b9c1) and [upcoming fixtures](https://mobbin.com/screens/7c3af29f-79f0-439c-9716-6900d5bf8f46).

Signed Debug **1.1.1 (7)**, bundle `com.keithbarney.sportssync`, app and extension, was installed and launched normally on Keith's iPhone 16 Pro. Device records confirmed the installed version/build. Source is `9c5d8aa` plus the existing working tree and these changes. App executable SHA-256: `500cdf9e9925a79656416f535372fffee4900fa907654dae44217361d9908953`. Evidence: `/tmp/sports-center-widget-phone-final.log`, `/tmp/sports-center-widget-phone-install.json`, `/tmp/sports-center-widget-phone-launch.json`, `/tmp/sports-center-widget-phone-apps.json`.

Native renderer review passed for all sizes in Light/Dark on the saved Sports iPhone simulator (iOS 26.5) using isolated, explicitly marked mock data: `/tmp/sports-center-widget-render.xcresult`, `/tmp/sports-center-widget-render-attachments`. Screenshots confirmed the new layout, readable crests and names, consistent metadata order, and truncation of long stadium names. Phone Home Screen appearance has not been directly inspected.

### Two medium / four large fixtures

Keith requested a denser version with two fixtures on medium and four on large. The initial denser version retained all five metadata fields when present; the final refinement omits the network on medium. The initial dense medium used eight-point content padding; this was restored to sixteen points after removing its network line, so the title clears the rounded corners. Medium uses smaller crests and time text; both sizes now use half-point metadata gaps. Explicit WidgetKit padding is mirrored by the Debug renderer. The small widget still shows one fixture.

Native Light/Dark renderer tests passed and the screenshots were inspected: `/tmp/sports-center-widget-dense-render.xcresult`, `/tmp/sports-center-widget-dense-render-attachments`. The review included long stadium names and two-line team names; text fits without overlapping adjacent fixtures.

Signed Debug **1.1.1 (8)** was installed on Keith's iPhone 16 Pro; device records confirmed version/build. Source is `9c5d8aa` plus the existing working tree and these changes. App executable SHA-256: `08fff47f32b8d00cddff75cc7f862eb6da43994b1a06b1d7a6c53811df9d0573`. Evidence: `/tmp/sports-center-widget-dense-phone.log`, `/tmp/sports-center-widget-dense-install.json`, `/tmp/sports-center-widget-dense-apps.json`. Initial launch verification was blocked by the phone being locked (`/tmp/sports-center-widget-dense-launch.json`).

The complete Home Screen resize test passed for small/medium/large and tap-through into Following, including the two/four fixture counts: `/tmp/sports-center-widget-dense-live.xcresult` (390.9 seconds; SpringBoard menus impose long idle waits).

Final refinement: large metadata spacing is half a point, with two points of padding above and below each divider; medium no longer displays the network line. Native Light/Dark review passed (`/tmp/sports-center-widget-polish-render.xcresult`, screenshots in `/tmp/sports-center-widget-polish-render-attachments`). Signed Debug **1.1.1 (9)** was installed and launched normally on Keith's iPhone 16 Pro; device records confirmed the version/build. App executable SHA-256: `7e77afbbfff2458dca2efa07a40d19bc5f6bf3e2315098e9c9f17e22bc070c10`. Source remains `9c5d8aa` plus the existing working tree and these changes. Evidence: `/tmp/sports-center-widget-polish-phone.log`, `/tmp/sports-center-widget-polish-install.json`, `/tmp/sports-center-widget-polish-launch.json`, `/tmp/sports-center-widget-polish-apps.json`.

The final live Home Screen test passed: medium displayed exactly two fixtures with stadium/competition and no network text, and tapping opened Following. Current large and medium screenshots were inspected: `/tmp/sports-center-widget-polish-live.xcresult`, `/tmp/sports-center-widget-polish-live-attachments`. Simulator remains in the isolated mock Following screen after tap-through; phone launch used normal personal data.

### Crests without containers

Removed circular backgrounds and extra image padding from the shared widget crest renderer, including the initials fallback. Native Light/Dark renderer and live Home Screen/tap-through tests both passed (two tests, zero failures): `/tmp/sports-widget-bare-crests.xcresult`. Inspected screenshots in `/tmp/sports-widget-bare-crests-attachments` confirm exposed crest artwork in small, medium and large, including the real medium Home Screen widget. The saved Sports iPhone simulator remains in its isolated mock widget review screen.

Signed Debug **1.1.1 (10)**, app and extension, was installed and launched on Keith's iPhone 16 Pro; device records confirmed version/build. Source is `9c5d8aa` plus the existing working tree and these changes. App executable SHA-256: `1d32e0c7a575ac787ef0e54a2a44985f2166a4d33d063e3582c2beae583c80f0`. Evidence: `/tmp/sports-widget-bare-crests-phone.log`, `/tmp/sports-widget-bare-crests-install.json`, `/tmp/sports-widget-bare-crests-launch.json`, `/tmp/sports-widget-bare-crests-apps.json`. Phone launch used normal personal data; phone Home Screen appearance was not directly captured.

### Simplified small widget

Small now displays the two teams, kickoff/date and competition, omitting the location and network rows. Medium and large retain their current layouts. The shared accessibility description still includes full fixture details.

Signed Debug **1.1.1 (11)** was installed and launched normally on Keith's iPhone 16 Pro; device records confirmed version/build. Source is `9c5d8aa` plus the existing working tree and these changes. App executable SHA-256: `2e102b9b1aaeff49ee2b69c47986aeda157344ca0fec9a57c416e4bea8c236b4`. Evidence: `/tmp/sports-widget-small-simple-phone.log`, `/tmp/sports-widget-small-simple-install.json`, `/tmp/sports-widget-small-simple-launch.json`, `/tmp/sports-widget-small-simple-apps.json`.

Native Light/Dark renderer review and the targeted small Home Screen test passed (two tests, zero failures): `/tmp/sports-widget-small-simple.xcresult`. Screenshots were inspected in `/tmp/sports-widget-small-simple-attachments`. The live test confirmed teams and competition remain, location/network are absent, and tapping opens Following. The saved Sports iPhone simulator remains in isolated mock Following after tap-through; the phone uses normal personal data.

### Medium title inset

Restored sixteen-point padding around the medium widget, matching small/large and keeping its title clear of the rounded top-left corner. The native Debug renderer uses the same padding. Two fixtures still fit because medium no longer includes network lines.

Native Light/Dark and medium Home Screen/tap-through tests passed (two tests, zero failures): `/tmp/sports-widget-medium-inset.xcresult`. Screenshots were inspected in `/tmp/sports-widget-medium-inset-attachments`; the title clears the corner and both fixtures fit. The saved Sports iPhone simulator remains in its isolated mock widget review screen.

Signed Debug **1.1.1 (12)**, app and extension, was installed and launched normally on Keith's iPhone 16 Pro; device records confirmed version/build. Source is `9c5d8aa` plus the existing working tree and these changes. App executable SHA-256: `a9a86f76dc1b4d3e787df486f960e0032db558db949c08903e9d9de697e3aa7e`. Evidence: `/tmp/sports-widget-medium-inset-phone.log`, `/tmp/sports-widget-medium-inset-install.json`, `/tmp/sports-widget-medium-inset-launch.json`, `/tmp/sports-widget-medium-inset-apps.json`. Phone launch used normal personal data.

### Crests only in compact sizes

Small and medium now show the opponents using crests without visible team names. Small pairs 32-point crests above its kickoff/date and competition; medium retains opposing 26-point crests around the centered details. Both use nine-point secondary metadata and fourteen-point kickoff text. Large retains its names and typography. Full team names and match details remain in the accessibility description, with initials as the existing missing-artwork fallback.

Signed Debug **1.1.1 (13)**, app and extension, was installed and launched normally on Keith's iPhone 16 Pro; device records confirmed version/build. Source is `9c5d8aa` plus the existing working tree and these changes. App executable SHA-256: `338afba1c61ed3250576711c108fab9cd1fd36d96776934d456fbcd63281b11b`. Evidence: `/tmp/sports-widget-crest-only-phone.log`, `/tmp/sports-widget-crest-only-install.json`, `/tmp/sports-widget-crest-only-launch.json`, `/tmp/sports-widget-crest-only-apps.json`. Phone launch used normal personal data.

Native Light/Dark renderer checks and both compact Home Screen/tap-through checks passed (three tests, zero failures): `/tmp/sports-widget-crest-only.xcresult`. Inspected screenshots in `/tmp/sports-widget-crest-only-attachments` confirm visible crests, absent compact team names, smaller metadata, and sufficient title inset. Both widget sizes open Following. The saved Sports iPhone simulator (iPhone 17 Pro Max, iOS 26.5) remains in isolated mock Following after tap-through. Phone Home Screen appearance was not directly captured.

### Larger compact crests and smaller large metadata

Small crests increased from 32 to 48 points and medium crests from 26 to 42 points to use the space freed by removing names. Large retains its crest/name layout, with secondary metadata reduced from ten to nine points and kickoff text from eighteen to sixteen points. All sizes retain the same fixture counts and metadata order.

Signed Debug **1.1.1 (14)**, app and extension, was installed and launched normally on Keith's iPhone 16 Pro; device records confirmed version/build. Source is `9c5d8aa` plus the existing working tree and these changes. App executable SHA-256: `0a6e71da5a22b8331c63c10cbca6b70496d06d77c01badd517375081e2af69a9`. Evidence: `/tmp/sports-widget-larger-crests-phone.log`, `/tmp/sports-widget-larger-crests-install.json`, `/tmp/sports-widget-larger-crests-launch.json`, `/tmp/sports-widget-larger-crests-apps.json`. Phone launch used normal personal data.

Native Home Screen resizing through small, medium and large, fixture counts, and tap-through into Following passed, along with Light/Dark renderer review (two tests, zero failures): `/tmp/sports-widget-larger-crests.xcresult`. Inspected renderer and all three Home Screen captures in `/tmp/sports-widget-larger-crests-attachments`; crests and metadata fit without overlap. The saved Sports iPhone simulator (iPhone 17 Pro Max, iOS 26.5) remains in the isolated mock widget renderer review. Phone Home Screen appearance was not directly captured.

### Crests only in every size

Removed visible team names from large as well as compact sizes. Reduced crest width and height by exactly ten percent: small 48 → 43.2 points, medium 42 → 37.8 points, large 30 → 27 points. Fixture counts, metadata and VoiceOver descriptions remain the same. The existing initials fallback remains for unavailable artwork.

Signed Debug **1.1.1 (15)**, app and extension, was installed and launched normally on Keith's iPhone 16 Pro; device records confirmed version/build. Source is `9c5d8aa` plus the existing working tree and these changes. App executable SHA-256: `b909bde8607024b862ef0641af0d98e5998e26cf90a1cc114aed71736fa601bb`. Evidence: `/tmp/sports-widget-all-crests-phone.log`, `/tmp/sports-widget-all-crests-install.json`, `/tmp/sports-widget-all-crests-launch.json`, `/tmp/sports-widget-all-crests-apps.json`. Phone launch used normal personal data.

Native Home Screen resizing, fixture-count checks and tap-through into Following passed for all three sizes, along with Light/Dark renderer review (two tests, zero failures): `/tmp/sports-widget-all-crests.xcresult`. Inspected captures in `/tmp/sports-widget-all-crests-attachments` confirm crests without team-name labels, reduced sizing and no content overlap. The saved Sports iPhone simulator (iPhone 17 Pro Max, iOS 26.5) remains in the isolated mock widget renderer review. Phone Home Screen appearance was not directly captured.

### Matching medium and large crests

Medium and large now share a 37.8-point crest size. Large's four-fixture count, metadata and spacing remain the same. The reusable Home Screen test supports a targeted large-size run to avoid rechecking unaffected sizes during small refinements.

Native large Home Screen content and tap-through checks plus Light/Dark renderer review passed (two tests, zero failures): `/tmp/sports-widget-matched-crests.xcresult`. Inspected captures in `/tmp/sports-widget-matched-crests-attachments` confirm matching medium/large crests and four large fixtures without overlap. The saved Sports iPhone simulator remains in isolated mock widget renderer review.

Signed Debug **1.1.1 (16)**, app and extension, was installed and launched normally on Keith's iPhone 16 Pro; device records confirmed version/build. Source is `9c5d8aa` plus the existing working tree and these changes. App executable SHA-256: `06fb5af43b134b8ae3bee175a882011a76df031ff4f9177b4fc7c104dd7d00c6`. Evidence: `/tmp/sports-widget-matched-crests-phone.log`, `/tmp/sports-widget-matched-crests-install.json`, `/tmp/sports-widget-matched-crests-launch.json`, `/tmp/sports-widget-matched-crests-apps.json`. Phone launch used normal personal data; phone Home Screen appearance was not directly captured.
