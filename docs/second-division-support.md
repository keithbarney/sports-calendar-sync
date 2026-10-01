# Second divisions and competition coverage

Added September 14, 2026. The supported second tiers are EFL Championship (`eng.2`), LaLiga 2 (`esp.2`), 2. Bundesliga (`ger.2`), Serie B (`ita.2`), and Ligue 2 (`fra.2`). Discover, filters, follow selection, refresh, and calendar sync use the existing competition-based code paths.

## Associated feeds

| Second tier | Existing national cups | Separate playoff feeds added |
| --- | --- | --- |
| Championship | FA Cup, Carabao Cup | Playoffs are in `eng.2` |
| LaLiga 2 | Copa del Rey | Playoffs are in `esp.2` |
| 2. Bundesliga | DFB-Pokal | `ger.playoff.relegation` (top-tier promotion), `ger.2.promotion.relegation` (second-tier relegation) |
| Serie B | Coppa Italia | Promotion/relegation playoffs are in `ita.2` |
| Ligue 2 | Coupe de France | `fra.1.promotion.relegation` (includes promotion rounds), `fra.2.promotion.relegation` (second-tier relegation) |

Club Friendlies (`club.friendly`) is also selectable where ESPN lists the club. Existing UEFA Champions League, Europa League, Conference League, super cups and FIFA club competitions remain available based on provider membership; second-tier clubs are not excluded from them.

## Live verification and limits

Read-only requests to `https://site.api.espn.com/apis/site/v2/sports/soccer/{slug}/teams?limit=1000` returned 24/22/18/20/18 clubs respectively. Darmstadt ID `3812` appears in `ger.2` and DFB-Pokal. September–October 2026 scoreboards returned matches for all five leagues. May–June 2026 scoreboards confirmed the embedded playoffs in England/Spain/Italy and the separate German and French top-tier playoff feeds.

The French second-tier relegation feed returned valid teams/scoreboard payloads but zero fixtures in the tested May–June 2025 and 2026 windows. It is supported as a feed, not a guarantee of complete provider coverage.

ESPN cup entrant lists can be incomplete before later rounds: this audit returned only 20 Copa del Rey entrants (none of the current LaLiga 2 clubs) and 11 of 18 Ligue 2 clubs in Coupe de France. The app does not invent membership or assume reserve teams are eligible. A supported cup becomes selectable for a club once the provider lists it. Existing saved follows remain editable when entrants disappear or requests fail. Promotion/relegation does not automatically change the user's selected competitions.

## Isolated review

Launch Debug with `-mock-data -mock-second-divisions`. Add `-screenshot-empty` to exercise initial following from Discover. This dataset includes ten verified bundled crests, five representative clubs, their cups, and fictional playoff/European qualification scenarios. It uses the existing in-memory store and blocks calendar/notification/network writes. It does not modify the approved marketing capture dataset or PNGs.

Tests cover all five leagues' competition discovery, cup entry points, persisted slugs, idempotent follow/sync into simulated calendars, and the native Darmstadt Discover → Follow → Manage Competitions → Following → Fixtures journey.

The production Swift decoders successfully read 72 downloaded live team/scoreboard payloads in `/tmp/sports-division-audit`. Full final unit suite: 39 tests passed. Native iPhone manual review verified selecting all five available mock Darmstadt competitions and loading five fixtures. The iPad automated flow did not complete because its SpringBoard accessibility automation crashed; see `widget-support.md` for the precise limitation.
