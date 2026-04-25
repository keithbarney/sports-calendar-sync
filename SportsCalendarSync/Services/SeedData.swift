import Foundation
import SwiftData

/// Debug-only — populates the DB with a starter set of teams when launched with `-seed-data`.
/// Fetches real ESPN team data (logo + colors) so the UI renders with real crests.
@MainActor
enum SeedData {
    static func populate(modelContext: ModelContext, espn: ESPNService) async {
        let descriptor = FetchDescriptor<TrackedTeam>()
        if let count = try? modelContext.fetchCount(descriptor), count > 0 { return }

        // One team per league. Match by substring of displayName so ESPN's
        // canonical team IDs don't need to be hardcoded (they drift — see CLAUDE.md note on LAFC).
        let starters: [(nameContains: String, league: League)] = [
            ("Manchester United",   .epl),
            ("Real Madrid",         .laLiga),
            ("Bayern Munich",       .bundesliga),
            ("Juventus",            .serieA),
            ("Paris Saint-Germain", .ligue1),
            ("LAFC",                .mls),
        ]

        for s in starters {
            guard let teams = try? await espn.getTeams(league: s.league),
                  let match = teams.first(where: {
                      ($0.displayName ?? $0.name ?? "").localizedCaseInsensitiveContains(s.nameContains)
                  }) else {
                continue
            }
            let team = TrackedTeam(
                espnId: match.id,
                leagueSlug: s.league.slug,
                name: match.displayName ?? match.name ?? "Unknown",
                shortDisplayName: match.shortDisplayName,
                abbreviation: match.abbreviation,
                logoURL: match.logos?.first?.href,
                primaryColor: match.color
            )
            modelContext.insert(team)
        }
        try? modelContext.save()
    }
}
