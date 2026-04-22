# Sports Calendar Sync

Soccer schedule tracker with native Apple Calendar sync. Follow your favorite teams across MLS + top 5 European leagues — upcoming games auto-sync to Apple Calendar via EventKit.

## Product Definition

- **Platform:** Native iOS (SwiftUI)
- **Data source:** ESPN hidden API (`site.api.espn.com`) — free, no auth, covers all target leagues
- **Calendar:** EventKit — direct write to Apple Calendar, real-time updates. Dedicated "Sports" calendar (green).
- **Notifications:** Push notifications before kickoff (in addition to calendar events)
- **Monetization:** Free at launch. StoreKit 2 IAP wiring deferred — model after ShowSync's disabled-paywall pattern if ever needed.
- **Target user:** Soccer fans who want match kickoffs on their personal calendar without checking ESPN/app every day
- **Accounts:** None — no login, no server. iCloud sync deferred to post-MVP.
- **Discovery:** Browse teams by league → follow → all upcoming fixtures auto-populate calendar

## Leagues (at launch)

- **MLS** — Major League Soccer (`usa.1`)
- **EPL** — English Premier League (`eng.1`)
- **La Liga** — Spanish Primera (`esp.1`)
- **Bundesliga** — German 1st division (`ger.1`)
- **Serie A** — Italian Serie A (`ita.1`)
- **Ligue 1** — French Ligue 1 (`fra.1`)

Post-launch candidates: UEFA Champions League (`uefa.champions`), Europa League, World Cup, FA Cup, Copa America.

## Architecture

- **Language:** Swift
- **UI:** SwiftUI
- **Data:** ESPN hidden API — teams, rosters, schedules, scores
- **Calendar integration:** EventKit framework — direct read/write to system Calendar
- **Persistence:** SwiftData (local only for now, CloudKit deferred)
- **Min target:** iOS 17+
- **Project generation:** xcodegen (`project.yml` → `.xcodeproj`)
- **Bundle ID:** `com.keithbarney.sportssync`
- **Widget Bundle ID:** `com.keithbarney.sportssync.widget`
- **Team ID:** `BXKNJTU253`
- **Secrets:** None required (ESPN API is unauthenticated). `Secrets.swift` stub retained for future paid-tier API swap.

## ESPN API — Base Endpoints

- **Base:** `https://site.api.espn.com/apis/site/v2/sports/soccer/{league}/`
- **Scoreboard (upcoming + live + recent):** `{base}/scoreboard`
- **Teams list:** `{base}/teams`
- **Team detail:** `{base}/teams/{teamId}`
- **Team schedule:** `{base}/teams/{teamId}/schedule`
- **Team roster:** `{base}/teams/{teamId}/roster`
- **Standings:** `https://site.api.espn.com/apis/v2/sports/soccer/{league}/standings`

League slugs map to the six above. Match objects return `competitions[0].competitors[]` with home/away, `date` (ISO8601), `venue.fullName`, and `broadcasts[]`.

## Key Services

- **TeamManager.swift** — centralized follow/unfollow for teams. All views route through this. Mirrors `MediaManager` in ShowSync.
- **CalendarService.swift** — EventKit wrapper. Creates "Sports" calendar, manages events. Ported from ShowSync with `addGame(...)` instead of `addShowEpisode`/`addMovieRelease`.
- **ESPNService.swift** — ESPN API client. In-memory `teamDetailCache`, `scheduleCache`. Endpoints: `getTeams(league:)`, `getTeam(league:teamId:)`, `getSchedule(league:teamId:)`, `getScoreboard(league:)`, `getRoster(league:teamId:)`.
- **SyncService.swift** — background fixture refresh. Fetches schedules for all followed teams, diffs against stored games, writes/updates/removes calendar events.

## Navigation

- **Floating bottom tab bar** — Upcoming + Discover + Profile (capsule, icon-only, glass material) — ported from ShowSync
- **Segmented filter** — All / MLS / EPL / La Liga / Bundesliga / Serie A / Ligue 1 (top, capsule container, scrollable if overflow; hidden on Profile)
- **No nav bar** — toolbar hidden
- **Home screen label:** "Sports" (`CFBundleDisplayName`), App Store name: "Sports Calendar Sync"
- **Back button:** Floating capsule overlaid on team crest / hero
- **Team detail** — `TeamDetailTemplate` shared layout: crest/hero, team name + league chip, form (last 5), upcoming fixtures list, standings position, 3-state action button (Follow/Following/Unfollow). Mirrors `DetailTemplate` in ShowSync.
- **Match detail** — optional v1.5: kickoff time, venue, broadcast, H2H, lineups

## Theme

- **Adaptive colors** — `Color+Theme.swift` uses `UIColor { traits in ... }` dynamic providers — ported from ShowSync
- **Glass materials** — `glassFill`, `glassBorder`, `glassShadow`, `glassHighlight`
- **AppSettings** — `@AppStorage("appearanceMode")` — System/Light/Dark
- **Default:** Dark mode
- **League accent colors:** each league gets its own accent used for chips + crest glow

## Figma

- **File:** TBD — create a `SportsSync` file and store key in `figma-sync.md`
- **Components to port from ShowSync:** FloatingTabBar, SegmentedFilter, FeedRow, FeedRowActionButton, PosterView (→ CrestView), SearchBar, SettingsRow, ActionButton, EmptyState, SkeletonView family, ToastView
- **New components:** LeagueChip, FormRow (W/L/D pills), StandingsRow, MatchCard (home/away crests + kickoff), BroadcastBadge

## App Store

- **App Store name:** Sports Calendar Sync
- **Subtitle:** Auto-sync fixtures to calendar
- **Bundle ID:** `com.keithbarney.sportssync`
- **App Store Connect:** TBD
- **Category:** Sports, Age rating: 4+
- **Encryption:** `ITSAppUsesNonExemptEncryption = NO` (HTTPS only)
- **PrivacyInfo.xcprivacy:** Declares UserDefaults API, no tracking, no data collection

## Icons

- **Lucide icons** — ported from ShowSync. Additions needed: `trophy`, `shield`, `calendar-clock`, `tv-2`, `flag`, `swords` (vs.), `list` (standings)
- **SF Symbols retained only for:** swipe action Labels, toast icons

## Skeleton Loading

- Port `SkeletonView`, `FeedRowSkeleton`, `DetailSkeleton`, `DiscoverSkeleton` from ShowSync. Rename per-domain where helpful (e.g., `MatchRowSkeleton`).

## Figma Sync

- Reuse the `/figma-push`, `/figma-pull`, `/figma-lint`, `/figma-sections`, `/figma-page-organizer` workflow from ShowSync
- **Figma is source of truth** — code always conforms to Figma
- **Dark Mode default** — `defaultMode: dark` in figma-sync.md

## Component Architecture

- **`FeedRow<Subtitle, Trailing>`** — ported from ShowSync; used for upcoming-match rows and team rows
- **`CrestView`** — equivalent of `PosterView`; loads ESPN team crest (`team.logos[0].href`) with fallback initials
- **Match row layout:** home crest · vs · away crest · kickoff time · broadcast badge
- **Team row layout:** crest · team name · league · follow button
- **Upcoming feed:** grouped by date with `.sectionHeader()` — identical pattern to ShowSync

## Dev Workflow

- **Project generate:** `xcodegen generate` (run after adding Swift files)
- **Build for phone:** `xcodebuild -project SportsCalendarSync.xcodeproj -scheme SportsCalendarSync -destination 'platform=iOS,id=<device-id>' -allowProvisioningUpdates build`
- **Simulator:** iPhone 16 — prefer phone for testing (same IPv6 caveat as ShowSync for third-party APIs)
- **Seed data (simulator):** Launch with `-seed-data` flag to follow a starter set of teams (e.g., Arsenal, LAFC, Real Madrid)
- **App Store upload:** Archive via Xcode Organizer (CLI upload not configured)

## Mistakes & Learnings (carry forward from ShowSync)

- xcodegen Info.plist must include `CFBundleIdentifier`, `CFBundleExecutable`, etc.
- `CalendarService.checkAuthorization()` must call `findOrCreateCalendar()` when already authorized
- TMDB-style date parsing caveats apply — ESPN dates are ISO8601 with timezone; parse with local tz
- xcodegen schemes must be explicitly defined in `project.yml`
- `ITSAppUsesNonExemptEncryption = false` to skip encryption prompt
- `UISupportedInterfaceOrientations` must include PortraitUpsideDown for iPad multitasking

## Mistakes & Learnings (sports-specific)

- **ESPN `/teams/{id}/schedule` only returns past matches for MLS** — confirmed 2026-04-22 with LAFC (id=18966): endpoint returned 8 past events, 0 future. EPL/La Liga endpoints behave similarly near season end. Fix: use `/scoreboard?dates=YYYYMMDD-YYYYMMDD` in 14-day chunks, filter events where the target team appears in `competitions[0].competitors`. See `ESPNService.getUpcomingFixtures`.
- **ESPN date format has NO seconds** — scoreboard returns `"2026-04-25T20:45Z"`, not `"2026-04-25T20:45:00Z"`. `ISO8601DateFormatter` rejects this. `parseDate` must fall back to a `DateFormatter` with `yyyy-MM-dd'T'HH:mmXXXXX`. Symptom when broken: ESPN returns N events, `merged=N`, but `calWrites=0` and 0 TrackedGame records inserted because every event is skipped at the kickoff `guard let`.
- **LAFC ESPN team ID is 18966**, not 11690. Always resolve team IDs from `/teams` response, never hardcode.
- **Seed data must match API-returned IDs** — using a wrong ID leaves sync silently returning 0 events.

## Sports-specific to watch for

- **Postponed / rescheduled matches** — ESPN updates `date` on the existing event. Sync must UPDATE the calendar event, not create a duplicate.
- **Live score updates** — out of scope for v1; calendar event title stays as-is after kickoff.
- **Timezone** — ESPN returns UTC; always convert to user's local tz.
- **Home & Away title convention:** `"Arsenal vs. Liverpool"` (home team first, localized "vs." separator).
- **Broadcast info** — populate event notes with `competitions[0].broadcasts[].names`.
- **All-day vs. timed:** always timed (kickoff is known). Runtime: 2h (105 min game + 15 min buffer).

## Dev Server Port

- N/A (native iOS)
