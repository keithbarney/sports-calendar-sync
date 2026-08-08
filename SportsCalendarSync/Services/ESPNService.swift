import Foundation
import os

private let logger = Logger(subsystem: "com.keithbarney.sportssync", category: "ESPNService")

struct UpcomingFixturesFetchResult {
    let eventsByTeamId: [String: [ESPNEvent]]
    let isComplete: Bool
    let failures: [String]
}

/// Client for ESPN's public (hidden) soccer API.
///
/// Base: `https://site.api.espn.com/apis/site/v2/sports/soccer/{league}/...`
/// No auth required. All calls return JSON.
@MainActor
final class ESPNService: ObservableObject {
    private let base = "https://site.api.espn.com/apis/site/v2/sports/soccer"

    // MARK: caches
    private var teamsCache: [String: [ESPNTeam]] = [:]           // keyed by league slug
    private var scheduleCache: [String: [ESPNEvent]] = [:]       // keyed by "{league}:{teamId}"

    private let iso = ISO8601DateFormatter()
    private let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    /// ESPN's scoreboard returns dates WITHOUT seconds: `"2026-04-25T20:45Z"`.
    /// ISO8601DateFormatter rejects that shape, so we fall back to this DateFormatter.
    private let isoNoSeconds: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mmXXXXX"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Teams

    func getTeams(league: League, useCache: Bool = true) async throws -> [ESPNTeam] {
        if useCache, let cached = teamsCache[league.slug] { return cached }

        let url = try buildURL("\(base)/\(league.slug)/teams")
        let response: ESPNTeamsResponse = try await fetch(url)
        let teams = response.sports
            .flatMap { $0.leagues }
            .flatMap { $0.teams }
            .map { $0.team }
        teamsCache[league.slug] = teams
        return teams
    }

    // MARK: - Schedule

    func getSchedule(league: League, teamId: String, useCache: Bool = true) async throws -> [ESPNEvent] {
        let key = "\(league.slug):\(teamId)"
        if useCache, let cached = scheduleCache[key] { return cached }

        let url = try buildURL("\(base)/\(league.slug)/teams/\(teamId)/schedule")
        let response: ESPNScheduleResponse = try await fetch(url)
        let events = response.events ?? []
        scheduleCache[key] = events
        return events
    }

    // MARK: - Scoreboard (all upcoming matches for a league on a given date)

    func getScoreboard(league: League, date: Date? = nil) async throws -> [ESPNEvent] {
        var path = "\(base)/\(league.slug)/scoreboard"
        if let date {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMdd"
            fmt.timeZone = TimeZone(identifier: "UTC")
            path += "?dates=\(fmt.string(from: date))"
        }
        let url = try buildURL(path)
        let response: ESPNScoreboardResponse = try await fetch(url)
        return response.events
    }

    /// Fetch upcoming fixtures for a team by sweeping the league scoreboard week-by-week
    /// and filtering events where the team appears. Works around the fact that
    /// `/teams/{id}/schedule` only exposes past matches for some leagues (notably MLS).
    func getUpcomingFixtures(league: League, teamId: String, weeksAhead: Int = 16) async throws -> [ESPNEvent] {
        let result = try await getUpcomingFixturesResult(
            league: league,
            teamIds: [teamId],
            weeksAhead: weeksAhead
        )
        guard result.isComplete else {
            throw APIError.incompleteFixtureCoverage(result.failures)
        }
        return result.eventsByTeamId[teamId] ?? []
    }

    /// Fetches each league window once and partitions matching events across followed teams.
    /// Partial results remain useful for inserts/updates, but `isComplete` must be true before
    /// a caller treats an absent event as removed.
    func getUpcomingFixturesResult(
        league: League,
        teamIds: Set<String>,
        weeksAhead: Int = 16
    ) async throws -> UpcomingFixturesFetchResult {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        fmt.timeZone = TimeZone(identifier: "UTC")

        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        var byTeam: [String: [String: ESPNEvent]] = Dictionary(
            uniqueKeysWithValues: teamIds.map { ($0, [:]) }
        )
        var failures: [String] = []

        // 14-day windows. 16 weeks ahead = 8 API calls.
        for offset in stride(from: 0, to: weeksAhead * 7, by: 14) {
            try Task.checkCancellation()
            guard let start = cal.date(byAdding: .day, value: offset, to: now),
                  let end   = cal.date(byAdding: .day, value: 13, to: start) else { continue }
            let range = "\(fmt.string(from: start))-\(fmt.string(from: end))"

            var components = URLComponents(string: "\(base)/\(league.slug)/scoreboard")!
            components.queryItems = [
                URLQueryItem(name: "dates", value: range),
                URLQueryItem(name: "limit", value: "300"),
            ]
            guard let url = components.url else { continue }

            do {
                let response: ESPNScoreboardResponse = try await fetch(url)
                var matches = 0
                for event in response.events {
                    let eventTeamIds = Set(
                        event.competitions.first?.competitors.map { $0.team.id } ?? []
                    )
                    for teamId in teamIds.intersection(eventTeamIds) {
                        byTeam[teamId, default: [:]][event.id] = event
                        matches += 1
                    }
                }
                print("[ESPN] \(range) events=\(response.events.count) matches=\(matches)")
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                print("[ESPN] chunk \(range) FAILED: \(error)")
                failures.append("\(range): \(error.localizedDescription)")
            }
        }

        let eventsByTeamId = byTeam.mapValues { events in
            events.values.sorted { $0.date < $1.date }
        }
        return UpcomingFixturesFetchResult(
            eventsByTeamId: eventsByTeamId,
            isComplete: failures.isEmpty,
            failures: failures
        )
    }

    // MARK: - Helpers

    /// Parse an ISO8601-ish date string from ESPN. Tries three shapes:
    /// 1. `2026-04-25T20:45:00.000Z` (fractional seconds)
    /// 2. `2026-04-25T20:45:00Z`     (full ISO8601)
    /// 3. `2026-04-25T20:45Z`        (no seconds — ESPN scoreboard/teams)
    func parseDate(_ string: String) -> Date? {
        if let d = isoFractional.date(from: string) { return d }
        if let d = iso.date(from: string) { return d }
        return isoNoSeconds.date(from: string)
    }

    // MARK: - Private

    private func buildURL(_ string: String) throws -> URL {
        guard let url = URL(string: string) else { throw APIError.invalidURL }
        return url
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw APIError.badResponse(status: http.statusCode)
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                logger.error("Decoding \(T.self) failed: \(error.localizedDescription)")
                throw APIError.decoding(error)
            }
        } catch let err as APIError {
            throw err
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.network(error)
        }
    }
}
