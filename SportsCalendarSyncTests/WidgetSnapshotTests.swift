import XCTest
@testable import SportsCalendarSync

final class WidgetSnapshotTests: XCTestCase {
    @MainActor
    func testUsesOnlyFollowedCompetitionsDeduplicatesBothOpponentsAndSortsByKickoff() {
        let now = Date(timeIntervalSince1970: 1_000)
        let teams = [team("a", "ger.2"), team("b", "ger.2"), team("c", "eng.2")]
        let duplicate = game("one", "b", "ger.2", 2_000)
        let snapshot = WidgetSnapshot.make(teams: teams, games: [
            game("later", "c", "eng.2", 4_000), game("one", "a", "ger.2", 2_000), duplicate,
            game("unfollowed", "x", "ger.2", 1_500), game("old-cup", "a", "ger.dfb_pokal", 1_500)
        ], now: now)
        XCTAssertEqual(snapshot.fixtures.map(\.id), ["ger.2:one", "eng.2:later"])
        XCTAssertEqual(snapshot.fixtures.first?.competition, "2. Bundesliga")
        XCTAssertTrue(snapshot.hasFollowedTeams)
        XCTAssertEqual(snapshot.upcoming(at: Date(timeIntervalSince1970: 2_000)).map(\.id), ["eng.2:later"])
    }

    @MainActor
    func testNewestDuplicateStatusWinsAndUnconfirmedOrFinishedMatchesAreExcluded() {
        let scheduled = game("changed", "a", "ger.2", 2_000)
        scheduled.lastUpdated = Date(timeIntervalSince1970: 1)
        let postponed = game("changed", "b", "ger.2", 2_000)
        postponed.status = "STATUS_POSTPONED"
        postponed.lastUpdated = Date(timeIntervalSince1970: 2)
        let excluded = ["STATUS_FINAL", "STATUS_FULL_TIME", "STATUS_IN_PROGRESS", "STATUS_HALFTIME", "STATUS_DELAYED", "STATUS_CANCELED", "STATUS_CANCELLED", "STATUS_ABANDONED", "STATUS_SUSPENDED"]
        let games = excluded.enumerated().map { index, status in
            let row = game("excluded-\(index)", "a", "ger.2", 2_000)
            row.status = status
            return row
        } + [scheduled, postponed, game("past", "a", "ger.2", 500), game("valid", "a", "ger.2", 3_000)]
        let snapshot = WidgetSnapshot.make(teams: [team("a", "ger.2"), team("b", "ger.2")], games: games,
                                           now: Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(snapshot.fixtures.map(\.id), ["ger.2:valid"])
    }

    @MainActor
    func testCrestReferencesSurviveSnapshotAndOldSnapshotsStillDecode() throws {
        let row = game("crests", "a", "ger.2", 2_000)
        row.homeTeamLogo = "https://a.espncdn.com/i/teamlogos/soccer/500/3812.png"
        row.awayTeamLogo = "https://a.espncdn.com/i/teamlogos/soccer/500/2428.png"
        row.venue = "  Carrow Road  "
        row.broadcasts = ["ESPN+", " ESPN+ ", " ", "ABC"]
        let snapshot = WidgetSnapshot.make(teams: [team("a", "ger.2")], games: [row], now: Date(timeIntervalSince1970: 1_000))
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded.fixtures.first?.homeLogoURL, row.homeTeamLogo)
        XCTAssertEqual(decoded.fixtures.first?.awayLogoURL, row.awayTeamLogo)
        XCTAssertEqual(decoded.fixtures.first?.venueLabel, "Carrow Road")
        XCTAssertEqual(decoded.fixtures.first?.broadcastLabel, "ESPN+, ABC")
        let legacy = Data(#"{"hasFollowedTeams":true,"fixtures":[{"id":"old","homeTeam":"Home","awayTeam":"Away","competition":"EPL","kickoff":1000}]}"#.utf8)
        let old = try JSONDecoder().decode(WidgetSnapshot.self, from: legacy).fixtures.first
        XCTAssertNil(old?.homeLogoURL)
        XCTAssertNil(old?.venueLabel)
        XCTAssertNil(old?.broadcastLabel)
    }

    @MainActor
    func testRemovingFollowClearsWidgetWhileStoredHistoryRemains() throws {
        let retainedHistory = [game("one", "a", "ger.2", 2_000)]
        let snapshot = WidgetSnapshot.make(teams: [], games: retainedHistory, now: Date(timeIntervalSince1970: 1_000))
        XCTAssertFalse(snapshot.hasFollowedTeams)
        XCTAssertTrue(snapshot.fixtures.isEmpty)
        XCTAssertEqual(try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(snapshot)), snapshot)
    }

    @MainActor
    private func team(_ id: String, _ slug: String) -> TrackedTeam {
        TrackedTeam(espnId: id, leagueSlug: slug, name: id)
    }

    @MainActor
    private func game(_ id: String, _ team: String, _ slug: String, _ time: TimeInterval) -> TrackedGame {
        TrackedGame(espnEventId: id, followedTeamId: team, leagueSlug: slug, homeTeamName: "Home", awayTeamName: "Away",
                    kickoff: Date(timeIntervalSince1970: time), status: "STATUS_SCHEDULED")
    }
}
