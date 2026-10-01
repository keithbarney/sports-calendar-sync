import XCTest
@testable import SportsCalendarSync

final class FollowingFixtureSummaryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    @MainActor
    func testChoosesEarliestFollowedCompetitionAndIgnoresUnfollowedHistory() {
        let teams = [team("club", "ger.2"), team("cup-club", "ger.dfb_pokal")]
        let summary = FollowingFixtureSummary.nextByClub(teams: teams, games: [
            game("league", "club", "ger.2", 4_000),
            game("cup", "cup-club", "ger.dfb_pokal", 2_000),
            game("unfollowed", "club", "uefa.champions", 1_100),
            game("other-team", "other", "ger.2", 1_200)
        ], now: now)["darmstadt"]
        XCTAssertEqual(summary?.eventKey, "ger.dfb_pokal:cup")
        XCTAssertEqual(summary?.matchup, "vs. Hannover 96")
        XCTAssertEqual(summary?.competition, Competition.dfbPokal.shortName)
    }

    @MainActor
    func testLatestDuplicateStatusWinsAndInvalidStatusesAreExcluded() {
        let scheduled = game("duplicate", "club", "ger.2", 2_000)
        scheduled.lastUpdated = Date(timeIntervalSince1970: 1)
        let postponed = game("duplicate", "opponent", "ger.2", 2_000)
        postponed.status = "STATUS_POSTPONED"
        postponed.lastUpdated = Date(timeIntervalSince1970: 2)
        let statuses = ["STATUS_FINAL", "STATUS_FULL_TIME", "STATUS_IN_PROGRESS", "STATUS_HALFTIME", "STATUS_DELAYED", "STATUS_CANCELED", "STATUS_CANCELLED", "STATUS_ABANDONED", "STATUS_SUSPENDED"]
        let invalid = statuses.enumerated().map { index, status in
            let row = game("invalid-\(index)", "club", "ger.2", 2_000)
            row.status = status
            return row
        }
        let next = FollowingFixtureSummary.nextByClub(teams: [team("club", "ger.2"), team("opponent", "ger.2", "Hannover 96")],
                                                      games: invalid + [scheduled, postponed, game("started", "club", "ger.2", 1_000), game("valid", "club", "ger.2", 3_000)], now: now)
        XCTAssertEqual(next["darmstadt"]?.eventKey, "ger.2:valid")
        XCTAssertNil(next[ESPNTeam.clubNameKey("Hannover 96")])
    }

    @MainActor
    func testAwayMatchUsesOpponentAndExpiredFixtureAdvancesWithoutRefresh() {
        let row = game("away", "club", "ger.2", 2_000)
        row.homeTeamName = "Hannover 96"
        row.awayTeamName = "Darmstadt"
        let later = game("later", "club", "ger.2", 3_000)
        let teams = [team("club", "ger.2")]
        XCTAssertEqual(FollowingFixtureSummary.nextByClub(teams: teams, games: [row, later], now: now)["darmstadt"]?.matchup, "at Hannover 96")
        XCTAssertEqual(FollowingFixtureSummary.nextByClub(teams: teams, games: [row, later], now: row.kickoff)["darmstadt"]?.eventKey, "ger.2:later")
        XCTAssertTrue(FollowingFixtureSummary.nextByClub(teams: teams, games: [row, later], now: later.kickoff).isEmpty)
    }

    @MainActor
    func testUnrecognizedNamesKeepFullMatchupAndTiesAreStable() {
        let first = game("a", "club", "ger.2", 2_000)
        first.homeTeamName = "Provider club name"
        let second = game("b", "club", "ger.2", 2_000)
        let next = FollowingFixtureSummary.nextByClub(teams: [team("club", "ger.2")], games: [second, first], now: now)["darmstadt"]
        XCTAssertEqual(next?.eventKey, "ger.2:a")
        XCTAssertEqual(next?.matchup, "Provider club name vs. Hannover 96")
    }

    @MainActor
    private func team(_ id: String, _ slug: String, _ name: String = "Darmstadt") -> TrackedTeam {
        TrackedTeam(espnId: id, leagueSlug: slug, name: name)
    }

    @MainActor
    private func game(_ id: String, _ team: String, _ slug: String, _ time: TimeInterval) -> TrackedGame {
        TrackedGame(espnEventId: id, followedTeamId: team, leagueSlug: slug, homeTeamName: "Darmstadt", awayTeamName: "Hannover 96",
                    kickoff: Date(timeIntervalSince1970: time), status: "STATUS_SCHEDULED")
    }
}
