import Foundation
import CryptoKit

/// A read-only projection for WidgetKit; the app's SwiftData store stays in its original container.
struct WidgetFixture: Codable, Equatable, Identifiable {
    let id: String
    let homeTeam: String
    let awayTeam: String
    let competition: String
    let kickoff: Date
    var homeLogoURL: String? = nil
    var awayLogoURL: String? = nil
    var venue: String? = nil
    var broadcasts: [String]? = nil

    var venueLabel: String? { venue?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
    var broadcastLabel: String? {
        var seen = Set<String>()
        let names = (broadcasts ?? []).compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct WidgetSnapshot: Codable, Equatable {
    let hasFollowedTeams: Bool
    let fixtures: [WidgetFixture]

    #if DEBUG
    static let groupID = "group.com.keithbarney.sportssync.local"
    #else
    static let groupID = "group.com.keithbarney.sportssync"
    #endif
    static let widgetKind = "SportsCalendarSyncWidget"
    static let filename = "upcoming-fixtures.json"
    static let artworkDidChange = Notification.Name("SportsWidgetArtworkDidChange")
    static let reviewFilename = "review-upcoming-fixtures.json"

    static func crestURL(for reference: String, review: Bool) -> URL? {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return nil }
        let hash = SHA256.hash(data: Data(reference.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(review ? "review-crests" : "crests")
            .appendingPathComponent(hash + ".png")
    }

    func upcoming(at date: Date) -> [WidgetFixture] {
        fixtures.filter { $0.kickoff > date }.sorted {
            $0.kickoff == $1.kickoff ? $0.id < $1.id : $0.kickoff < $1.kickoff
        }
    }

    @MainActor
    static func make(teams: [TrackedTeam], games: [TrackedGame], now: Date = Date()) -> WidgetSnapshot {
        let followed = Set(teams.map { "\($0.leagueSlug):\($0.espnId)" })
        let excluded = ["FINAL", "FULL_TIME", "IN_PROGRESS", "HALFTIME", "DELAYED", "POSTPONED", "CANCELED", "CANCELLED", "ABANDONED", "SUSPENDED"]
        var byEvent: [String: TrackedGame] = [:]
        for game in games where followed.contains("\(game.leagueSlug):\(game.followedTeamId)") {
            let key = "\(game.leagueSlug):\(game.espnEventId)"
            // Resolve duplicate follows before filtering: the newest status wins.
            if let existing = byEvent[key], existing.lastUpdated >= game.lastUpdated { continue }
            byEvent[key] = game
        }
        var fixtures: [WidgetFixture] = []
        for game in byEvent.values {
            let status = (game.status ?? "").uppercased()
            guard game.kickoff > now, !excluded.contains(where: { status.contains($0) }) else { continue }
            let competition = League(rawValue: game.leagueSlug)?.shortName ?? game.leagueSlug
            fixtures.append(WidgetFixture(id: "\(game.leagueSlug):\(game.espnEventId)", homeTeam: game.homeTeamName,
                                          awayTeam: game.awayTeamName, competition: competition, kickoff: game.kickoff,
                                          homeLogoURL: game.homeTeamLogo, awayLogoURL: game.awayTeamLogo,
                                          venue: game.venue, broadcasts: game.broadcasts))
        }
        fixtures.sort { left, right in
            if left.kickoff == right.kickoff { return left.id < right.id }
            return left.kickoff < right.kickoff
        }
        return WidgetSnapshot(hasFollowedTeams: !teams.isEmpty, fixtures: Array(fixtures.prefix(60)))
    }
}
