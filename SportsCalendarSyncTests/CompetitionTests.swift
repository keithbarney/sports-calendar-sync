import XCTest
@testable import SportsCalendarSync

final class CompetitionTests: XCTestCase {
    func testManchesterUnitedCompetitions() {
        XCTAssertEqual(
            Competition.recommendedCompetitions(forTeamNamed: "Manchester United"),
            [.epl, .championsLeague, .faCup, .carabaoCup]
        )
    }

    func testLAFCCompetitions() {
        XCTAssertEqual(
            Competition.recommendedCompetitions(forTeamNamed: "Los Angeles FC"),
            [.mls, .concacafChampionsCup, .leaguesCup]
        )
    }

    func testUnknownTeamHasNoHardCodedCompetitionBundle() {
        XCTAssertTrue(Competition.recommendedCompetitions(forTeamNamed: "Arsenal").isEmpty)
    }

    func testCompetitionFeedIdentifiers() {
        XCTAssertEqual(Competition.championsLeague.slug, "uefa.champions")
        XCTAssertEqual(Competition.faCup.slug, "eng.fa")
        XCTAssertEqual(Competition.carabaoCup.slug, "eng.league_cup")
        XCTAssertEqual(Competition.concacafChampionsCup.slug, "concacaf.champions")
        XCTAssertEqual(Competition.leaguesCup.slug, "concacaf.leagues.cup")
    }
}
