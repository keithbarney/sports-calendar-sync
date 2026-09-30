import XCTest
@testable import SportsCalendarSync

final class FixtureFeedTests: XCTestCase {
    @MainActor
    func testRejectedDateRangesFallBackToTeamFixturesWithinRequestedWindow() async throws {
        let result = try await service().getUpcomingFixturesResult(league: .bundesliga2, teamIds: ["3812"], weeksAhead: 2)
        XCTAssertTrue(result.isComplete)
        XCTAssertEqual(result.eventsByTeamId["3812"]?.map(\.id), ["ger.2-next"])
    }

    @MainActor
    func testFailedTeamFallbackPreservesPartialEventsWithoutClaimingCompleteCoverage() async throws {
        let result = try await service().getUpcomingFixturesResult(league: .bundesliga2, teamIds: ["3812", "failed"], weeksAhead: 2)
        XCTAssertFalse(result.isComplete)
        XCTAssertEqual(result.eventsByTeamId["3812"]?.count, 1)
        XCTAssertEqual(result.failures.count, 1)
    }

    @MainActor
    func testMissingFixtureListIsNotAnAuthoritativeEmptySchedule() async throws {
        let result = try await service(mode: "missing-events").getUpcomingFixturesResult(league: .bundesliga2, teamIds: ["3812"], weeksAhead: 2)
        XCTAssertFalse(result.isComplete)
    }

    @MainActor
    func testSuccessfulScoreboardStillWorksWithoutTeamFallback() async throws {
        let result = try await service(mode: "scoreboard").getUpcomingFixturesResult(league: .bundesliga2, teamIds: ["3812"], weeksAhead: 2)
        XCTAssertTrue(result.isComplete)
        XCTAssertEqual(result.eventsByTeamId["3812"]?.map(\.id), ["ger.2-next"])
    }

    @MainActor
    func testPreviewIncludesCupAndLeagueWithResolvedIDsAndChronologicalOrder() async throws {
        let result = try await service().getClubFixturePreview(for: darmstadt, source: .bundesliga2,
                                                               competitions: [.bundesliga2, .dfbPokal])
        XCTAssertTrue(result.unavailable.isEmpty)
        XCTAssertEqual(result.upcoming.map(\.competition), [.dfbPokal, .bundesliga2])
        XCTAssertEqual(result.upcoming.map(\.event.id), ["ger.dfb_pokal-next", "ger.2-next"])
        XCTAssertEqual(Set(result.recent.map(\.competition)), [.bundesliga2, .dfbPokal])
        XCTAssertEqual(result.recent.count, 2)
    }

    @MainActor
    func testPreviewRetainsAvailableFixturesWhenAnotherCompetitionFails() async throws {
        let result = try await service(mode: "failed-cup").getClubFixturePreview(for: darmstadt, source: .bundesliga2,
                                                                               competitions: [.bundesliga2, .dfbPokal])
        XCTAssertEqual(result.unavailable, [.dfbPokal])
        XCTAssertEqual(result.upcoming.map(\.competition), [.bundesliga2])
    }

    private var darmstadt: ESPNTeam {
        ESPNTeam(id: "3812", name: "SV Darmstadt 98", displayName: "SV Darmstadt 98",
                 shortDisplayName: nil, abbreviation: nil, color: nil, logos: nil)
    }

    @MainActor
    private func service(mode: String = "fallback") -> ESPNService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureFeedProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Fixture-Test": mode]
        return ESPNService(session: URLSession(configuration: configuration))
    }
}

private final class FixtureFeedProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let url = request.url!
        let path = url.pathComponents
        let slug = path[path.firstIndex(of: "soccer")! + 1]
        let mode = request.value(forHTTPHeaderField: "X-Fixture-Test")
        var status = 200
        var body: [String: Any] = [:]
        if path.last == "teams" {
            body = ["sports": [["leagues": [["teams": [["team": ["id": "cup-alias", "displayName": "SV Darmstadt 98"]]]]]]]]
        } else if path.last == "scoreboard" {
            status = mode == "scoreboard" ? 200 : 400
            body = ["events": [event(slug: slug, teamId: "3812", suffix: "next", days: 5)]]
        } else {
            let teamId = path[path.count - 2]
            let fixture = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains { $0.name == "fixture" && $0.value == "true" } == true
            if teamId == "failed" || mode == "scoreboard" || (mode == "failed-cup" && slug == "ger.dfb_pokal") {
                status = 503
            } else if mode != "missing-events" {
                let next = event(slug: slug, teamId: teamId, suffix: "next", days: slug == "ger.2" ? 5 : 2)
                let past = event(slug: slug, teamId: teamId, suffix: "past", days: -2)
                body = ["events": fixture ? [next, next, past, event(slug: slug, teamId: teamId, suffix: "distant", days: 200)] : [past, next]]
            }
        }
        let data = try! JSONSerialization.data(withJSONObject: body)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private func event(slug: String, teamId: String, suffix: String, days: Int) -> [String: Any] {
        let date = ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double(days) * 86400))
        return ["id": "\(slug)-\(suffix)", "date": date, "name": "Darmstadt vs Opponent",
                "competitions": [["id": "\(slug)-\(suffix)", "date": date,
                                  "competitors": [["id": teamId, "homeAway": "home", "team": ["id": teamId, "displayName": "SV Darmstadt 98"]]]]]]
    }
}
