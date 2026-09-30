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
    func testSecondDivisionClubsDiscoverCupsEuropeAndSeparatePlayoffs() async throws {
        for (id, name, source, expected) in [
            ("3812", "SV Darmstadt 98", Competition.bundesliga2, Set<Competition>([.bundesliga2, .dfbPokal, .bundesligaPlayoff, .clubFriendlies])),
            ("381", "Norwich City", .championship, [.championship, .faCup, .carabaoCup]),
            ("6832", "Almería", .laLiga2, [.laLiga2, .copaDelRey]),
            ("2923", "Palermo", .serieB, [.serieB, .coppaItalia, .europaLeague]),
            ("178", "Saint-Étienne", .ligue2, [.ligue2, .coupeDeFrance, .ligue1Playoff, .conferenceLeague])
        ] {
            let result = try await makeService().getCompetitions(for: team(id, name), source: source)
            XCTAssertEqual(Set(result.competitions), expected, name)
            XCTAssertTrue(result.unavailable.isEmpty)
        }
    }

    @MainActor
    func testDarmstadtOpenedFromCupFindsSecondDivisionWithoutFirstDivision() async throws {
        let result = try await makeService().getCompetitions(for: team("3812", "SV Darmstadt 98"), source: .dfbPokal)
        XCTAssertTrue(result.competitions.contains(.bundesliga2))
        XCTAssertFalse(result.competitions.contains(.bundesliga))
    }

    func testSavedSecondDivisionAndPlayoffSlugsRemainEditableWithoutEntrantData() throws {
        let slugs = ["eng.2", "esp.2", "ger.2", "ita.2", "fra.2", "ger.playoff.relegation",
                     "ger.2.promotion.relegation", "fra.1.promotion.relegation", "fra.2.promotion.relegation", "club.friendly"]
        for slug in slugs {
            let competition = try XCTUnwrap(Competition(rawValue: slug))
            let encoded = try JSONEncoder().encode(competition)
            XCTAssertEqual(try JSONDecoder().decode(Competition.self, from: encoded), competition)
            XCTAssertEqual(Competition.selectionOptions(source: nil, discovered: [], followed: [competition]), [competition])
        }
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
        // Fictional cup/European qualification is deliberately not hardcoded in production.
        let secondTierMembers: [String: [(String, String)]] = [
            "ger.2": [("3812", "SV Darmstadt 98")], "ger.dfb_pokal": [("3812", "SV Darmstadt 98")],
            "ger.playoff.relegation": [("3812", "SV Darmstadt 98")], "club.friendly": [("3812", "SV Darmstadt 98")],
            "eng.2": [("381", "Norwich City")], "eng.fa": [("381", "Norwich City")], "eng.league_cup": [("381", "Norwich City")],
            "esp.2": [("6832", "Almería")], "esp.copa_del_rey": [("6832", "Almería")],
            "ita.2": [("2923", "Palermo")], "ita.coppa_italia": [("2923", "Palermo")], "uefa.europa": [("2923", "Palermo")],
            "fra.2": [("178", "Saint-Étienne")], "fra.coupe_de_france": [("178", "Saint-Étienne")],
            "fra.1.promotion.relegation": [("178", "Saint-Étienne")], "uefa.europa.conf": [("178", "Saint-Étienne")]
        ]
        for member in secondTierMembers[slug] ?? [] {
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
