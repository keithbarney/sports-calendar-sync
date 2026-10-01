import Foundation

/// One upcoming match per followed club, projected from the existing local schedule.
struct FollowingFixtureSummary: Equatable {
    let eventKey: String
    let matchup: String
    let kickoff: Date
    let competition: String

    @MainActor
    static func nextByClub(teams: [TrackedTeam], games: [TrackedGame], now: Date) -> [String: FollowingFixtureSummary] {
        let teamsByFollow = Dictionary(grouping: teams) { "\($0.leagueSlug):\($0.espnId)" }
        var latestByEvent: [String: TrackedGame] = [:]
        var clubsByEvent: [String: Set<String>] = [:]
        for game in games {
            guard let owners = teamsByFollow["\(game.leagueSlug):\(game.followedTeamId)"] else { continue }
            let eventKey = "\(game.leagueSlug):\(game.espnEventId)"
            clubsByEvent[eventKey, default: []].formUnion(owners.map { ESPNTeam.clubNameKey($0.name) })
            if let existing = latestByEvent[eventKey], existing.lastUpdated >= game.lastUpdated { continue }
            latestByEvent[eventKey] = game
        }

        let excluded = ["FINAL", "FULL_TIME", "IN_PROGRESS", "HALFTIME", "DELAYED", "POSTPONED", "CANCELED", "CANCELLED", "ABANDONED", "SUSPENDED"]
        let aliasesByClub = Dictionary(grouping: teams, by: { ESPNTeam.clubNameKey($0.name) })
            .mapValues { follows in
                Set(follows.flatMap { [$0.name, $0.shortDisplayName].compactMap { $0 }.map(ESPNTeam.clubNameKey) })
            }
        var result: [String: FollowingFixtureSummary] = [:]
        for (eventKey, game) in latestByEvent {
            let status = (game.status ?? "").uppercased()
            guard game.kickoff > now, !excluded.contains(where: { status.contains($0) }) else { continue }
            for club in clubsByEvent[eventKey] ?? [] {
                if let existing = result[club],
                   existing.kickoff < game.kickoff || (existing.kickoff == game.kickoff && existing.eventKey < eventKey) { continue }
                let aliases = aliasesByClub[club] ?? []
                let matchup: String
                if aliases.contains(ESPNTeam.clubNameKey(game.homeTeamName)) {
                    matchup = "vs. \(game.awayTeamName)"
                } else if aliases.contains(ESPNTeam.clubNameKey(game.awayTeamName)) {
                    matchup = "at \(game.homeTeamName)"
                } else {
                    // Preserve the full matchup when provider names cannot identify home/away reliably.
                    matchup = game.title
                }
                result[club] = FollowingFixtureSummary(eventKey: eventKey, matchup: matchup, kickoff: game.kickoff,
                                                      competition: Competition(rawValue: game.leagueSlug)?.shortName ?? game.leagueSlug)
            }
        }
        return result
    }
}
