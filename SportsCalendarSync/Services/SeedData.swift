import Foundation
import SwiftData

/// Debug-only — populates the DB with a starter set of teams when launched with `-seed-data`.
enum SeedData {
    static func populate(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<TrackedTeam>()
        if let count = try? modelContext.fetchCount(descriptor), count > 0 { return }

        let starters: [(espnId: String, league: League, name: String)] = [
            ("359",  .epl,        "Arsenal"),
            ("382",  .epl,        "Liverpool"),
            ("86",   .laLiga,     "Real Madrid"),
            ("83",   .laLiga,     "Barcelona"),
            ("132",  .bundesliga, "Bayern Munich"),
            ("111",  .serieA,     "Juventus"),
            ("160",  .ligue1,     "Paris Saint-Germain"),
            ("11690",.mls,        "Los Angeles FC"),
        ]

        for s in starters {
            let team = TrackedTeam(
                espnId: s.espnId,
                leagueSlug: s.league.slug,
                name: s.name
            )
            modelContext.insert(team)
        }
        try? modelContext.save()
    }
}
