import Foundation
import os

private let logger = Logger(subsystem: "com.keithbarney.sportssync", category: "ESPNService")

struct UpcomingFixturesFetchResult {
    let eventsByTeamId: [String: [ESPNEvent]]
    let isComplete: Bool
    let failures: [String]
}

struct CompetitionFixture: Identifiable {
    let event: ESPNEvent
    let competition: Competition
    var id: String { event.id }
}

struct ClubFixturePreview {
    let upcoming: [CompetitionFixture]
    let recent: [CompetitionFixture]
    let unavailable: [Competition]
}

struct ClubCompetitionsResult {
    let competitions: [Competition]
    let unavailable: [Competition]
}

/// Client for ESPN's public (hidden) soccer API.
///
/// Base: `https://site.api.espn.com/apis/site/v2/sports/soccer/{league}/...`
/// No auth required. All calls return JSON.
@MainActor
final class ESPNService: ObservableObject {
    private let base = "https://site.api.espn.com/apis/site/v2/sports/soccer"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

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
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return ScreenshotFixtures.teams[league] ?? [] }
        #endif
        if useCache, let cached = teamsCache[league.slug] { return cached }

        // Cup fields exceed ESPN's default page size (Copa del Rey has 126 teams).
        let url = try buildURL("\(base)/\(league.slug)/teams?limit=1000")
        let response: ESPNTeamsResponse = try await fetch(url)
        let teams = response.sports
            .flatMap { $0.leagues }
            .flatMap { $0.teams }
            .map { $0.team }
        teamsCache[league.slug] = teams
        return teams
    }

    /// Resolve membership from the provider, including clubs opened from a cup feed.
    /// Failed requests are not cached as empty fields and can be retried on reopening.
    func getCompetitions(for team: ESPNTeam, source: Competition) async throws -> ClubCompetitionsResult {
        var matches: [Competition] = [source]
        var unavailable: [Competition] = []
        for competition in Competition.allCases where competition != source {
            try Task.checkCancellation()
            do {
                let teams = try await getTeams(league: competition)
                if teams.contains(where: { $0.matchesClub(team) }) {
                    matches.append(competition)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                unavailable.append(competition)
            }
        }
        return ClubCompetitionsResult(competitions: matches, unavailable: unavailable)
    }

    // MARK: - Schedule

    func getSchedule(league: League, teamId: String, useCache: Bool = true) async throws -> [ESPNEvent] {
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return ScreenshotFixtures.events(league: league, teamId: teamId) }
        #endif
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
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return ScreenshotFixtures.events(league: league) }
        #endif
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

    /// Fetch upcoming fixtures using league scoreboards, with fixture-enabled team
    /// schedules as a fallback. The default team schedule can contain only results,
    /// while some leagues reject the scoreboard's date-range requests.
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
        #if DEBUG
        if ScreenshotFixtures.isEnabled { return UpcomingFixturesFetchResult(eventsByTeamId: Dictionary(uniqueKeysWithValues: teamIds.map { ($0, ScreenshotFixtures.events(league: league, teamId: $0)) }), isComplete: true, failures: []) }
        #endif
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
                // Some feeds (including ger.2) reject date ranges entirely.
                if case APIError.badResponse(status: 400) = error { break }
            }
        }

        if !failures.isEmpty {
            var fallbackFailures: [String] = []
            let end = cal.date(byAdding: .day, value: weeksAhead * 7, to: now) ?? now
            for teamId in teamIds.sorted() {
                try Task.checkCancellation()
                do {
                    let url = try buildURL("\(base)/\(league.slug)/teams/\(teamId)/schedule?fixture=true&limit=1000")
                    let response: ESPNScheduleResponse = try await fetch(url)
                    // A missing events key is not an authoritative empty schedule.
                    guard let events = response.events else {
                        throw APIError.incompleteFixtureCoverage(["Missing fixture list"])
                    }
                    for event in events {
                        guard let date = parseDate(event.date),
                              date >= cal.startOfDay(for: now), date < end,
                              event.competitions.contains(where: { $0.competitors.contains(where: { $0.team.id == teamId }) }) else { continue }
                        byTeam[teamId, default: [:]][event.id] = event
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    fallbackFailures.append("\(teamId): \(error.localizedDescription)")
                }
            }
            // Successful team fixture feeds cover the requested window. Otherwise,
            // retain partial events and prevent sync from removing absent matches.
            failures = fallbackFailures
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

    /// Read-only preview across the club's detected competitions, with feed identity
    /// retained for each match. Failures must never be presented as an empty schedule.
    func getClubFixturePreview(for team: ESPNTeam, source: Competition,
                               competitions: [Competition]) async throws -> ClubFixturePreview {
        var upcoming: [String: CompetitionFixture] = [:]
        var recent: [String: CompetitionFixture] = [:]
        var unavailable: [Competition] = []
        let now = Date()
        for competition in competitions {
            try Task.checkCancellation()
            do {
                let teamId: String
                if competition == source {
                    teamId = team.id
                } else {
                    let teams = try await getTeams(league: competition)
                    guard let matching = teams.first(where: { $0.matchesClub(team) }) else {
                        unavailable.append(competition)
                        continue
                    }
                    teamId = matching.id
                }
                let result = try await getUpcomingFixturesResult(league: competition, teamIds: [teamId])
                if !result.isComplete { unavailable.append(competition) }
                for event in result.eventsByTeamId[teamId] ?? [] {
                    guard let date = parseDate(event.date), date >= now.addingTimeInterval(-3 * 60 * 60),
                          event.status?.type?.completed != true else { continue }
                    upcoming[event.id] = CompetitionFixture(event: event, competition: competition)
                }
                let past = try await getSchedule(league: competition, teamId: teamId, useCache: false)
                for event in past {
                    guard let date = parseDate(event.date), date < now,
                          upcoming[event.id] == nil else { continue }
                    recent[event.id] = CompetitionFixture(event: event, competition: competition)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                unavailable.append(competition)
            }
        }
        let orderedUpcoming = upcoming.values.sorted { parseDate($0.event.date)! < parseDate($1.event.date)! }
        let orderedRecent = recent.values.sorted { parseDate($0.event.date)! > parseDate($1.event.date)! }
        return ClubFixturePreview(upcoming: orderedUpcoming, recent: Array(orderedRecent.prefix(5)),
                                  unavailable: Competition.allCases.filter(Set(unavailable).contains))
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
        #if DEBUG
        if ScreenshotFixtures.isEnabled { throw APIError.invalidURL }
        #endif
        do {
            let (data, response) = try await session.data(from: url)
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
