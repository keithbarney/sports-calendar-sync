import XCTest
@testable import SportsCalendarSync

final class CompetitionTests: XCTestCase {
    func testSavedCupFollowsRemainEditableWhenDiscoveryFailsOrEntrantsChange() {
        XCTAssertEqual(
            Competition.selectionOptions(source: .laLiga, discovered: [], followed: [.championsLeague, .copaDelRey]),
            [.laLiga, .championsLeague, .copaDelRey]
        )
    }

    func testSelectionOptionsDeduplicateSourceAndSavedCompetitions() {
        XCTAssertEqual(
            Competition.selectionOptions(source: .laLiga, discovered: [.laLiga, .copaDelRey], followed: [.copaDelRey]),
            [.laLiga, .copaDelRey]
        )
    }

    func testClubMatchingHandlesSharedIDsAndAccentedNamesWithoutMatchingAbbreviations() {
        XCTAssertTrue(team("86", "Real Madrid").matchesClub(team("86", "Real Madrid CF")))
        XCTAssertTrue(team("1", "Atlético Madrid").matchesClub(team("2", "Atletico Madrid")))
        XCTAssertTrue(team("1", "LAFC").matchesClub(team("2", "Los Angeles FC")))
        XCTAssertFalse(team("1", "Manchester United").matchesClub(team("2", "Manchester City")))
        XCTAssertFalse(team("1", "").matchesClub(team("2", "")))
    }

    @MainActor
    func testRealMadridIsFoundBeyondDefaultCupPageAndFromACupEntryPoint() async throws {
        let service = makeService()
        let result = try await service.getCompetitions(for: team("86", "Real Madrid"), source: .championsLeague)
        XCTAssertEqual(Set(result.competitions), [.laLiga, .championsLeague, .copaDelRey, .spanishSuperCup])
        XCTAssertFalse(result.competitions.contains(.europaLeague))
        XCTAssertFalse(result.competitions.contains(.dfbPokal))
        XCTAssertTrue(result.unavailable.isEmpty)
    }

    @MainActor
    func testOtherDomesticLeaguesDiscoverTheirCupsWithoutNameSpecificBundles() async throws {
        for (id, name, league, cup) in [
            ("132", "Bayern Munich", Competition.bundesliga, Competition.dfbPokal),
            ("111", "Juventus", .serieA, .coppaItalia),
            ("160", "Paris Saint-Germain", .ligue1, .coupeDeFrance),
            ("359", "Arsenal", .epl, .faCup),
            ("9726", "Seattle Sounders FC", .mls, .usOpenCup)
        ] {
            let result = try await makeService().getCompetitions(for: team(id, name), source: league)
            XCTAssertEqual(Set(result.competitions), [league, cup], name)
        }
    }

    @MainActor
    func testFailedCompetitionFeedIsReportedRatherThanTreatedAsNoMembership() async throws {
        let service = makeService(failCopaDelRey: true)
        let result = try await service.getCompetitions(for: team("86", "Real Madrid"), source: .laLiga)
        XCTAssertEqual(result.unavailable, [.copaDelRey])
        XCTAssertTrue(result.competitions.contains(.laLiga))
        XCTAssertTrue(result.competitions.contains(.championsLeague))
    }

    @MainActor
    private func makeService(failCopaDelRey: Bool = false) -> ESPNService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CompetitionFeedProtocol.self]
        // Each test session controls its own failure through a request header.
        configuration.httpAdditionalHeaders = ["X-Test-Fail-Copa": failCopaDelRey ? "yes" : "no"]
        return ESPNService(session: URLSession(configuration: configuration))
    }

    private func team(_ id: String, _ name: String) -> ESPNTeam {
        ESPNTeam(id: id, name: name, displayName: name, shortDisplayName: nil, abbreviation: "FC", color: nil, logos: nil)
    }
}

private final class CompetitionFeedProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let url = request.url!
        let slug = url.pathComponents.dropLast().last!
        let fail = slug == "esp.copa_del_rey" && request.value(forHTTPHeaderField: "X-Test-Fail-Copa") == "yes"
        let members: [String: (String, String)] = [
            "esp.1": ("86", "Real Madrid"), "uefa.champions": ("86", "Real Madrid"),
            "esp.super_cup": ("86", "Real Madrid"), "esp.copa_del_rey": ("86", "Real Madrid"),
            "ger.dfb_pokal": ("132", "Bayern Munich"), "ita.coppa_italia": ("111", "Juventus"),
            "fra.coupe_de_france": ("160", "Paris Saint-Germain"), "eng.fa": ("359", "Arsenal"),
            "usa.open": ("9726", "Seattle Sounders FC")
        ]
        var teams: [[String: Any]] = []
        if let member = members[slug] {
            if slug == "esp.copa_del_rey" {
                teams = (0..<125).map { ["team": ["id": "other-\($0)", "displayName": "Cup club \($0)"]] }
            }
            teams.append(["team": ["id": member.0, "displayName": member.1]])
        }
        let limit = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "limit" }?.value.flatMap(Int.init) ?? 50
        let data = try! JSONSerialization.data(withJSONObject: ["sports": [["leagues": [["teams": Array(teams.prefix(limit))]]]]])
        let response = HTTPURLResponse(url: url, statusCode: fail ? 503 : 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
