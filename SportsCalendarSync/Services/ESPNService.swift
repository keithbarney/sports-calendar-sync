import Foundation
import os

private let logger = Logger(subsystem: "com.keithbarney.sportssync", category: "ESPNService")

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
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        fmt.timeZone = TimeZone(identifier: "UTC")

        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        var byId: [String: ESPNEvent] = [:]

        // 14-day windows. 16 weeks ahead = 8 API calls.
        for offset in stride(from: 0, to: weeksAhead * 7, by: 14) {
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
                    let plays = event.competitions.first?.competitors.contains(where: { $0.team.id == teamId }) ?? false
                    if plays { byId[event.id] = event; matches += 1 }
                }
                print("[ESPN] \(range) events=\(response.events.count) matches=\(matches)")
            } catch {
                print("[ESPN] chunk \(range) FAILED: \(error)")
                continue
            }
        }

        return byId.values.sorted { $0.date < $1.date }
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
        } catch {
            throw APIError.network(error)
        }
    }
}
