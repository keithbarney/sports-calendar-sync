import Foundation

struct DiscoveryTeam: Identifiable {
    let team: ESPNTeam
    let competition: Competition

    var id: String { team.id }
    var name: String { team.displayName ?? team.name ?? "Unknown team" }

    /// Domestic leagues come first so a club's search result opens its home league.
    static let domesticLeagues: [Competition] = [
        .epl, .laLiga, .bundesliga, .serieA, .ligue1, .mls,
        .championship, .laLiga2, .bundesliga2, .serieB, .ligue2
    ]

    static var competitionOrder: [Competition] {
        domesticLeagues + Competition.allCases.filter { !domesticLeagues.contains($0) }
    }

    static func uniqueTeams(in catalog: [Competition: [ESPNTeam]]) -> [DiscoveryTeam] {
        var seenIDs: Set<String> = []
        var seenNames: Set<String> = []
        var result: [DiscoveryTeam] = []
        for competition in competitionOrder {
            for team in catalog[competition] ?? [] {
                let names = Set([team.displayName, team.name].compactMap { $0 }
                    .map(ESPNTeam.clubNameKey)).subtracting([""])
                let isDuplicate = seenIDs.contains(team.id) || !seenNames.isDisjoint(with: names)
                seenIDs.insert(team.id)
                seenNames.formUnion(names)
                if !isDuplicate { result.append(DiscoveryTeam(team: team, competition: competition)) }
            }
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func search(_ query: String, in teams: [DiscoveryTeam]) -> [DiscoveryTeam] {
        let key = ESPNTeam.clubNameKey(query)
        guard !key.isEmpty else { return [] }
        return teams.filter { entry in
            [entry.team.displayName, entry.team.name, entry.team.shortDisplayName, entry.team.abbreviation]
                .compactMap { $0 }.contains { ESPNTeam.clubNameKey($0).contains(key) }
        }
    }
}

enum PopularTeams {
    // CIES Football Observatory Weekly Post 548, official social accounts, May 2026.
    // This is a dated editorial selection, not app usage or a live ranking.
    static let sourceURL = URL(string: "https://football-observatory.com/Most-popular-clubs-on-social-media-3733")!
    static let names = [
        "Real Madrid", "Barcelona", "Manchester United", "Paris Saint-Germain",
        "Manchester City", "Liverpool", "Juventus", "Bayern Munich", "Chelsea", "Arsenal"
    ]

    static func select(from teams: [DiscoveryTeam]) -> [DiscoveryTeam] {
        names.compactMap { name in
            teams.first { entry in
                [entry.team.displayName, entry.team.name].compactMap { $0 }
                    .contains { ESPNTeam.clubNameKey($0) == ESPNTeam.clubNameKey(name) }
            }
        }
    }
}
