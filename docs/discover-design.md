# Discover: Popular teams

## Design and native behavior

Discover starts with global team search, followed by a horizontally swipeable **Popular teams** carousel and compact competition browsing. Search returns each club once across supported competitions and prefers its domestic league as the detail entry point. Second divisions remain accessible through search and All competitions.

The implementation uses SwiftUI List, Section, ScrollView, LazyHStack, GroupBox, NavigationLink, Button, Form, and the existing native competition-selection sheet. View-aligned scrolling snaps the carousel to team cards. A partial next card signals horizontal browsing. Crests use the existing artwork component; card and crest sizes scale with Dynamic Type. System colors and controls handle Light and Dark appearances.

Each card opens team details and offers Follow or Following. Following a new team opens the existing competition picker, with all found supported competitions selected initially. A followed club has a compact checkmark in search and competition lists. Catalog loading publishes available results progressively, retains successful results after partial failures, and offers Retry for unavailable competitions.

### Follow controls refinement

The user's supplied Discover-list screenshot is the reference for the September 14 control refinement. Search and competition lists use an outlined blue `plus.circle` and a filled blue `checkmark.circle.fill` at a base size of 22 points. Popular cards replace the small gray text pills with larger filled blue plus/check circles at 32 points. These are native SF Symbols inside standard SwiftUI buttons or navigation links, with minimum 44-point hit areas and scaled symbol sizes. VoiceOver retains team-specific Follow/Manage labels and the Following state. Loading retains the same minimum area so the control does not collapse during a request.

The existing Apple TV carousel reference still governs the card layout; the user's screenshot governs the revised actions. Follow continues to open the competition picker, and a followed card's checkmark opens details. No change to stored follows or competition-selection behavior.

## References inspected

- [Apple TV club carousel on Mobbin](https://mobbin.com/screens/c13e5e28-1e82-49d4-8870-d5a5d794d4b6): crest tiles, names below, partial next item. Adapted the layout with native follow buttons and system styling.
- [Apple TV club detail flow](https://mobbin.com/flows/c05670e5-3da3-4d95-9a0d-f0a53cec1465): club browsing leads into a dedicated detail page. The inspected carousel/detail screens informed the navigation.
- [Apple Music horizontal content row](https://mobbin.com/screens/2309c3c2-2208-4d78-b8f5-7754acbaeec8): artwork-led horizontal browsing with titles below provided a second reference.

## Popularity selection

The initial ten are a dated editorial selection from [CIES Football Observatory Weekly Post 548](https://football-observatory.com/Most-popular-clubs-on-social-media-3733), published May 27, 2026. Its May 2026 combined official-account followers across Facebook, Instagram, TikTok, X and YouTube determine the order:

1. Real Madrid
2. Barcelona
3. Manchester United
4. Paris Saint-Germain
5. Manchester City
6. Liverpool
7. Juventus
8. Bayern Munich
9. Chelsea
10. Arsenal

This is neither a live ranking nor a measurement of Sports Sync usage or unique supporters. The native information sheet states the date and basis and links to the source. Update `PopularTeams.names` deliberately when adopting a newer ranking. Selection uses names matched to the loaded ESPN catalog, not hardcoded provider IDs. All ten were verified in live ESPN domestic-league directories with crest URLs on September 14, 2026. Missing entries are omitted until their competition loads.

## Validation

- All 51 unit tests passed on the saved iPad Air 13-inch (M4), iOS 26.5. Five new tests cover deduplication, normalized search, second-division discovery, distinct clubs sharing abbreviations, ranking order, missing entries, and bundled mock artwork.
- Three native iPhone tests passed on Sports Sync Screenshot 1.1.0 (iPhone 17 Pro Max), iOS 26.5: swipe through all ten clubs; follow Barcelona across three mock competitions and reopen details; search without duplicate clubs and check empty results; browse 2. Bundesliga and open Darmstadt.
- Ordinary native review uses opt-in `-mock-data` with the persistent review header, isolated in-memory stores and external-write protections. The second-division journey additionally uses `-mock-second-divisions`. Phone delivery uses normal launch arguments and preserves personal data.
- Initial evidence: `/tmp/sports-discover-unit.xcresult` and `/tmp/sports-discover-final-ui.xcresult`. Screenshot inspection found a Follow-button sizing issue in list rows; the final refinement explicitly preserves the native button's full label and intrinsic size.

### Final layout review

- The two affected iPhone row/search journeys passed after the native Follow-button sizing fix: `/tmp/sports-discover-row-ui.xcresult`. Inspected search, second-division and Dark carousel captures in `/tmp/sports-discover-row-attachments`.
- iPad carousel/follow and second-division journeys passed in `/tmp/sports-discover-ipad-ui.xcresult`. Its search test initially lost keyboard focus after clearing the field; the test now taps the native search field again before typing. That journey passed in `/tmp/sports-discover-ipad-final-ui.xcresult`. Inspected Light/Dark carousel and search captures from these results.
- Both saved simulators were left on Discover in the Typical library mock scenario. Final iPhone review capture: `/tmp/sports-discover-final-iphone.png`. These are development review captures with the mock header, not App Store marketing images.
- `git diff --check` passed. The final incremental signed build completed without warnings in `/tmp/sports-discover-phone-final.log`; earlier full builds emitted existing unrelated service/toolchain warnings.

### Phone delivery

Installed and launched **Sports Sync (L) 1.1.1 (17)** on Keith's iPhone 16 Pro on September 14, 2026. `devicectl device info apps` confirmed the installed version and build. Normal launch, no mock arguments. The Debug development build includes the app and widget extension; this was not an App Store upload.

- Bundle: `com.keithbarney.sportssync`
- Source: `9c5d8aa` plus the existing uncommitted project work and this Discover change.
- Artifact: `/tmp/sports-center-widget-phone/Build/Products/Debug-iphoneos/SportsCalendarSync.app`
- Main executable SHA-256: `04d6866931fae5a9fbcb5554f6210880e3e0498709fecd170cfa5904d0e47e25`
- Evidence: `/tmp/sports-discover-install.json`, `/tmp/sports-discover-launch.json`, `/tmp/sports-discover-apps.json`.

### Follow control delivery — build 18

Installed and launched **1.1.1 (18)** on Keith's iPhone 16 Pro; the installed version/build was confirmed through `devicectl`. Same bundle, Debug configuration, artifact path, and source revision plus uncommitted work as above. Personal data was preserved, with normal phone launch arguments. Executable SHA-256: `4478daf22436c1511624cd2dfb47c1f984bd6db8fe3b2c8210194eafeef02f96`.

Three native iPhone journeys and two native iPad journeys passed on the saved iOS 26.5 simulators. Coverage includes tapping the new list plus, opening and canceling the competition picker, following from a Popular card, reopening through its checkmark, carousel scrolling, search and second-division navigation. Light/Dark captures were inspected. Existing unit logic was unchanged; no additional unit suite was needed for this presentation refinement. `git diff --check` and the signed app/widget build passed.

- Results: `/tmp/sports-discover-actions-ui.xcresult`, `/tmp/sports-discover-actions-ipad.xcresult`.
- Captures: `/tmp/sports-discover-actions-attachments`, `/tmp/sports-discover-actions-ipad-attachments`.
- Delivery: `/tmp/sports-discover-actions-phone.log`, `/tmp/sports-discover-actions-install.json`, `/tmp/sports-discover-actions-launch.json`, `/tmp/sports-discover-actions-apps.json`.
- Saved iPhone simulator left on Discover, Dark appearance, Typical library mock scenario with the review header.

### Green Following state — build 19

Following checkmarks now use system green in Popular cards and team lists. The plus controls retain their existing style. Native iPhone search/list and carousel/follow journeys both passed; Light and Dark captures were inspected in `/tmp/sports-discover-green-attachments` (result: `/tmp/sports-discover-green-ui.xcresult`). This color-only change does not alter follow behavior or layout.

Built, installed and launched **1.1.1 (19)** on Keith's iPhone 16 Pro, with installed version verified. Same Debug bundle/artifact and source revision plus uncommitted work as above. Executable SHA-256: `d8575ba37b8879d60d9ef1f04b7fa08bdb18657625a3006d56b1808c52cc829a`. Evidence: `/tmp/sports-discover-green-phone.log`, `/tmp/sports-discover-green-install.json`, `/tmp/sports-discover-green-launch.json`, `/tmp/sports-discover-green-apps.json`.

### Consistent outline/filled states — build 20

Popular cards now use an outlined blue `plus.circle`, matching the team lists. Following remains a filled green checkmark throughout Discover. Native search/follow-picker review passed on the saved iPhone, and the Dark carousel capture was visually checked in `/tmp/sports-discover-outline-attachments` (result: `/tmp/sports-discover-outline-ui.xcresult`). Saved iPhone simulator left on Discover in Dark, Typical library mock mode.

Built, installed, launched and verified **1.1.1 (20)** on Keith's iPhone 16 Pro with the same Debug bundle/artifact and source revision plus uncommitted work. Executable SHA-256: `fd8f0829b57c8dcb99a27c56415de84f3f98b03898a16679018a99bdce3af0ec`. Evidence: `/tmp/sports-discover-outline-phone.log`, `/tmp/sports-discover-outline-install.json`, `/tmp/sports-discover-outline-launch.json`, `/tmp/sports-discover-outline-apps.json`.

### Blue outline/filled states — build 21

The selected styling is now blue throughout Discover: outlined plus for Follow and filled checkmark for Following, in both Popular cards and team lists. Native iPhone search/follow-picker review passed and the Dark carousel capture was inspected (`/tmp/sports-discover-blue-ui.xcresult`, `/tmp/sports-discover-blue-attachments`). Saved iPhone simulator left on Discover in Dark, Typical library mock mode.

Built, installed, launched and verified **1.1.1 (21)** on Keith's iPhone 16 Pro with the same Debug bundle/artifact and source revision plus uncommitted work. Executable SHA-256: `682094480cfaf97112a8a24b815f304aaa45af2b14d3acb9c8839f4137c60ad5`. Evidence: `/tmp/sports-discover-blue-phone.log`, `/tmp/sports-discover-blue-install.json`, `/tmp/sports-discover-blue-launch.json`, `/tmp/sports-discover-blue-apps.json`. `git diff --check` passed.

## Competition artwork

Discover's competition rows now place a 40-point, aspect-fit logo beside the name and country. The same native HStack/NavigationLink composition is used in All competitions. The badge scales with Dynamic Type and is hidden from VoiceOver because the adjacent name identifies it.

Bundled asset-catalog images cover all eleven supported domestic leagues and sixteen cups, with published Dark variants where available. These display immediately offline and work in isolated mock review without separate screenshot-only artwork. ESPN scoreboard metadata supplies most competition-to-logo mappings. The official [Lega Serie A site](https://www.legaseriea.it/supercoppa) supplies the current Serie A Enilive and Italian Supercup badges. The [Ligue 1 brand center](https://ligueun.brandcenter.lfp.fr/logotype/) and [Ligue 2 brand center](https://liguedeux.brandcenter.lfp.fr/logotype/) supply high-resolution Light/Dark marks. These replace outdated ESPN artwork found during native visual review. Source URLs and file hashes are recorded in `docs/competition-artwork-sources.json`.

The four promotion/relegation feeds use their corresponding domestic league badges. German Supercup, Trophée des Champions, Community Shield and FIFA Intercontinental Cup use a native trophy icon because the checked catalog has no usable badge. Club Friendlies uses a native soccer-ball icon. Generic ESPN team placeholders are excluded from competition branding.

### Validation and delivery — build 22

Six Discovery unit tests passed, including bundled artwork coverage for both appearances. After replacing stale source images, the artwork coverage test and two native iPhone journeys passed again. Reviewed Discover, All competitions and Dark carousel captures. The native journey opens All competitions, enters 2. Bundesliga, opens Darmstadt and navigates back; search/follow-picker/empty behavior also passed. The saved iPhone simulator is left on Discover in Dark, Typical library mock mode. Results: `/tmp/sports-competition-logos-final-unit.xcresult`, `/tmp/sports-competition-logos-final-ui.xcresult`; captures: `/tmp/sports-competition-logos-final-attachments`.

Installed and launched **1.1.1 (22)** on Keith's iPhone 16 Pro; `devicectl` confirmed the installed version/build. Same Debug bundle, app/widget artifact path and source revision plus uncommitted work as above. Executable SHA-256: `0b007de12a175e0bf2c0b753a49743238eb803280fb3ed1307f19db7f0763736`. Evidence: `/tmp/sports-competition-logos-final-phone.log`, `/tmp/sports-competition-logos-install.json`, `/tmp/sports-competition-logos-launch.json`, `/tmp/sports-competition-logos-apps.json`. `git diff --check` passed.

## September 16 — card visibility and complete team previews

Popular teams keep native GroupBox cards, now using `secondarySystemGroupedBackground` so white cards contrast with the Light grouped page and adapt to Dark. Native Light/Dark carousel swiping and Follow-sheet checks passed in `/tmp/sports-card-background-review.xcresult`; both captures were inspected.

Team details now discovers and lists all supported competition feeds when opened, including before following. Followed competitions are labeled, and Manage competitions keeps its existing selection behavior. Opening a followed team performs read-only competition discovery; automatic schedule sync remains owned by the app-level refresh. Unfollowed previews aggregate available upcoming/recent matches across detected competitions, resolve each feed's team ID, deduplicate event IDs, sort chronologically, and retain the competition label on each match.

Live diagnosis on September 16: Darmstadt (`3812`) had five recent results at the default `ger.2` team schedule, while all date-range scoreboard requests returned HTTP 400. The fixture-enabled schedule (`schedule?fixture=true&limit=1000`) returned 29 future league events. The cup feed returned Elversberg on October 27 and the friendly feed returned San Antonio on September 29. The next league match was Wolfsburg away on September 18 at 16:30 UTC. These are provider observations, not mock fixtures or guaranteed broadcast listings.

The shared upcoming-fetch service now falls back to fixture-enabled team schedules when scoreboard coverage fails, bounded by the existing requested horizon. Missing fixture lists and failed fallbacks retain incomplete status so sync preserves absent saved matches. Team previews keep successful competition results and show unavailable/partial coverage rather than reporting a failed request as zero fixtures.

Validation: 17 focused tests passed (fallback recovery, date bounds, deduplication, partial failure, missing responses, competition-specific IDs, aggregate preview ordering, existing discovery and decoding). Native iPhone tests passed for Popular follow/manage behavior and an unfollowed Darmstadt preview covering league and cup fixtures, all competition names, and canceling the follow sheet. The second-division mock dataset deliberately includes fictional playoffs for coverage; it is not a claim that Darmstadt currently participates in five competitions. Results: `/tmp/sports-darmstadt-unit.xcresult`, `/tmp/sports-darmstadt-ui.xcresult`, `/tmp/sports-darmstadt-final-ui.xcresult`. Development captures stay in `/tmp/sports-darmstadt-attachments` and `/tmp/sports-darmstadt-final-attachments`, outside the marketing screenshot set.

Installed and launched the updated Debug **Sports Sync (L) 1.1.2 (1789454004)** on Keith’s iPhone 16 Pro. Version/build were confirmed through devicectl; source is `9c5d8aa` plus uncommitted work. Executable SHA-256: `fc26fba8b1c5b6cce76f5402348cdfc01afcf89d693fec9efbbf605893920566`. Evidence: `/tmp/sports-darmstadt-build-manifest.json`, `/tmp/sports-darmstadt-install.json`, `/tmp/sports-darmstadt-launch.json`, `/tmp/sports-darmstadt-after.json`. Normal phone launch, no mock arguments or App Store upload.

## September 16 — build delivery 1789570067

Signed Debug app and widget build completed from source `9c5d8aa821a554534978ada6e87ababeddb55d31` plus the existing uncommitted working tree. Marketing version remains **1.1.2**; bundle is `com.keithbarney.sportssync`. Executable SHA-256: `824b540a7207c7f09ddb89d0be741a2a4416119792276f1e3dcc7783163b4007`. Evidence: `/tmp/sports-card-background-phone.log`, `/tmp/sports-card-background-phone-install.json`, `/tmp/sports-card-background-phone-launch.json`, `/tmp/sports-card-background-phone-apps.json`, `/tmp/sports-card-background-phone-executable.sha256`.

Installed over the existing app on Keith’s iPhone 16 Pro (`00008140-00062DD0022A801C`) without resetting data, launched normally with no arguments, and confirmed via `devicectl` as **Sports Sync (L) 1.1.2 (1789570067)**. No upload or submission performed.
