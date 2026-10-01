import XCTest
import UIKit
@testable import SportsCalendarSync

final class DiscoveryTeamTests: XCTestCase {
    func testSearchDeduplicatesCupAliasesAndPrefersDomesticLeague() {
        let madrid = team("86", "Real Madrid")
        let catalog: [Competition: [ESPNTeam]] = [
            .laLiga: [madrid], .championsLeague: [team("86", "Real Madrid CF")],
            .copaDelRey: [team("other-id", "Real Madrid")]
        ]
        let results = DiscoveryTeam.search("madrid", in: DiscoveryTeam.uniqueTeams(in: catalog))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.competition, .laLiga)
    }

    func testSearchFindsSecondDivisionClubsAndIgnoresAccentsAndWhitespace() {
        let entries = DiscoveryTeam.uniqueTeams(in: [
            .bundesliga2: [team("3812", "SV Darmstadt 98")],
            .laLiga2: [team("6832", "Almería")],
            .dfbPokal: [team("3812", "SV Darmstadt 98")]
        ])
        XCTAssertEqual(DiscoveryTeam.search(" darmstadt ", in: entries).count, 1)
        XCTAssertEqual(DiscoveryTeam.search("almeria", in: entries).first?.name, "Almería")
        XCTAssertTrue(DiscoveryTeam.search("  ", in: entries).isEmpty)
        XCTAssertTrue(DiscoveryTeam.search("no such team", in: entries).isEmpty)
    }

    func testDistinctClubsWithSameAbbreviationAreNotMerged() {
        let entries = DiscoveryTeam.uniqueTeams(in: [.epl: [team("1", "Manchester United"), team("2", "Manchester City")]])
        XCTAssertEqual(entries.count, 2)
    }

    func testPopularSelectionPreservesPublishedOrderAndSkipsUnavailableTeams() {
        let teams = PopularTeams.names.reversed().enumerated().map {
            DiscoveryTeam(team: team(String($0.offset), $0.element), competition: .epl)
        }
        XCTAssertEqual(PopularTeams.select(from: teams).map(\.name), PopularTeams.names)
        XCTAssertEqual(PopularTeams.select(from: teams.filter { $0.name != "Real Madrid" }).count, 9)
    }

    @MainActor
    func testMockCatalogHasAllTenPopularClubsWithBundledCrests() {
        ScreenshotFixtures.argumentsForTesting = ["-mock-data"]
        defer { ScreenshotFixtures.argumentsForTesting = nil }
        let popular = PopularTeams.select(from: DiscoveryTeam.uniqueTeams(in: ScreenshotFixtures.teams))
        XCTAssertEqual(popular.map(\.name), PopularTeams.names)
        for club in popular { XCTAssertNotNil(ScreenshotFixtures.artwork(for: club.team.crestURL), club.name) }
    }

    func testCompetitionArtworkIsBundledForEveryLeagueAndDeclaredCup() {
        for league in DiscoveryTeam.domesticLeagues {
            XCTAssertNotNil(league.logoAssetName, league.displayName)
        }
        for competition in Competition.allCases {
            guard let asset = competition.logoAssetName else { continue }
            for appearance in [UIUserInterfaceStyle.light, .dark] {
                XCTAssertNotNil(UIImage(named: asset, in: .main,
                                       compatibleWith: UITraitCollection(userInterfaceStyle: appearance)),
                                "Missing \(asset) in \(appearance)")
            }
        }
    }

    private func team(_ id: String, _ name: String) -> ESPNTeam {
        ESPNTeam(id: id, name: name, displayName: name, shortDisplayName: nil,
                 abbreviation: "FC", color: nil, logos: nil)
    }
}
