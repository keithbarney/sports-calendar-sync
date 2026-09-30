import Foundation
import SwiftData
import UIKit

#if DEBUG
/// Explicit capture mode: fictional fixtures, no persistent model store or live integrations.
@MainActor
enum ScreenshotFixtures {
    static var argumentsForTesting: [String]?
    private static var arguments: [String] { argumentsForTesting ?? CommandLine.arguments }
    static var isCapturing: Bool { arguments.contains("-screenshot-fixtures") }
    static var isEnabled: Bool { isCapturing || arguments.contains("-mock-data") }
    static var isEmpty: Bool { arguments.contains("-screenshot-empty") }
    static var launchScenario: MockReviewScenario {
        guard let index = arguments.firstIndex(of: "-mock-scenario"),
              index + 1 < arguments.count,
              let scenario = MockReviewScenario(rawValue: arguments[index + 1]) else { return .typical }
        return scenario
    }
    static var referenceDate: Date {
        if let index = arguments.firstIndex(of: "-screenshot-date"), index + 1 < arguments.count,
           let date = ISO8601DateFormatter().date(from: arguments[index + 1]) { return date }
        return Calendar.current.startOfDay(for: Date())
    }
    static let artworkIDs: Set<String> = [
        "screenshot-united", "screenshot-real-madrid", "screenshot-bayern",
        "screenshot-juventus", "screenshot-psg", "screenshot-lafc",
        "catalog-arsenal", "catalog-chelsea", "catalog-liverpool", "catalog-man-city",
        "catalog-barcelona", "catalog-atletico", "catalog-dortmund", "catalog-leverkusen",
        "catalog-inter", "catalog-ac-milan", "catalog-napoli", "catalog-marseille",
        "catalog-monaco", "catalog-lyon", "catalog-galaxy", "catalog-seattle", "catalog-miami"
    ]

    /// Separate review dataset; approved marketing fixtures remain unchanged.
    static var isSecondDivisionReview: Bool { isEnabled && !isCapturing && arguments.contains("-mock-second-divisions") }
    static let secondDivisionArtworkIDs: Set<String> = ["review-3812", "review-2428", "review-381", "review-376", "review-6832", "review-3747", "review-2923", "review-2734", "review-178", "review-3243"]

    /// Decode bundled provider artwork synchronously so capture never races a download.
    static func artwork(for reference: String?) -> UIImage? {
        guard isEnabled, let reference, let url = URL(string: reference),
              url.scheme == "mock-crest", let id = url.host, (artworkIDs.contains(id) || secondDivisionArtworkIDs.contains(id)) else { return nil }
        return UIImage(named: "mock-crest-" + id)
    }

    private static func team(_ id: String, _ name: String, _ abbreviation: String) -> ESPNTeam {
        ESPNTeam(id: id, name: name, displayName: name, shortDisplayName: name,
                 abbreviation: abbreviation, color: "DA291C",
                 logos: (artworkIDs.contains(id) || secondDivisionArtworkIDs.contains(id)) ? [ESPNLogo(href: "mock-crest://" + id)] : nil)
    }
    static let united = team("screenshot-united", "Manchester United", "MUN")
    static let realMadrid = team("screenshot-real-madrid", "Real Madrid", "RMA")
    static let bayern = team("screenshot-bayern", "Bayern Munich", "BAY")
    static let juventus = team("screenshot-juventus", "Juventus", "JUV")
    static let psg = team("screenshot-psg", "Paris Saint-Germain", "PSG")
    static let lafc = team("screenshot-lafc", "LAFC", "LAFC")
    static let arsenal = team("catalog-arsenal", "Arsenal", "ARS")
    static let chelsea = team("catalog-chelsea", "Chelsea", "CHE")
    static let liverpool = team("catalog-liverpool", "Liverpool", "LIV")
    static let manCity = team("catalog-man-city", "Manchester City", "MCI")
    static let barcelona = team("catalog-barcelona", "Barcelona", "BAR")
    static let atletico = team("catalog-atletico", "Atlético Madrid", "ATM")
    static let dortmund = team("catalog-dortmund", "Borussia Dortmund", "BVB")
    static let leverkusen = team("catalog-leverkusen", "Bayer Leverkusen", "B04")
    static let inter = team("catalog-inter", "Inter Milan", "INT")
    static let acMilan = team("catalog-ac-milan", "AC Milan", "MIL")
    static let napoli = team("catalog-napoli", "Napoli", "NAP")
    static let marseille = team("catalog-marseille", "Marseille", "OM")
    static let monaco = team("catalog-monaco", "Monaco", "ASM")
    static let lyon = team("catalog-lyon", "Lyon", "OL")
    static let galaxy = team("catalog-galaxy", "LA Galaxy", "LA")
    static let seattle = team("catalog-seattle", "Seattle Sounders", "SEA")
    static let miami = team("catalog-miami", "Inter Miami", "MIA")
    private static let marketingTeams: [League: [ESPNTeam]] = [
        .mls: [lafc, galaxy, seattle, miami], .concacafChampionsCup: [lafc, miami, galaxy, seattle], .leaguesCup: [lafc, miami, galaxy, seattle],
        .epl: [united, arsenal, chelsea, liverpool, manCity], .faCup: [united, arsenal, chelsea, liverpool, manCity],
        .championsLeague: [united, realMadrid, bayern, juventus, psg, barcelona],
        .laLiga: [realMadrid, barcelona, atletico], .copaDelRey: [realMadrid, barcelona, atletico],
        .bundesliga: [bayern, dortmund, leverkusen], .dfbPokal: [bayern, dortmund, leverkusen],
        .serieA: [juventus, inter, acMilan, napoli], .coppaItalia: [juventus, inter, acMilan, napoli],
        .ligue1: [psg, marseille, monaco, lyon], .coupeDeFrance: [psg, marseille, monaco, lyon]
    ]

    static let darmstadt = team("review-3812", "SV Darmstadt 98", "SVD")
    static let hannover = team("review-2428", "Hannover 96", "H96")
    static let norwich = team("review-381", "Norwich City", "NOR")
    static let southampton = team("review-376", "Southampton", "SOU")
    static let almeria = team("review-6832", "Almería", "ALM")
    static let granada = team("review-3747", "Granada", "GRA")
    static let palermo = team("review-2923", "Palermo", "PAL")
    static let sampdoria = team("review-2734", "Sampdoria", "SAM")
    static let saintEtienne = team("review-178", "Saint-Étienne", "ASSE")
    static let reims = team("review-3243", "Stade de Reims", "REI")

    static var teams: [League: [ESPNTeam]] {
        guard isSecondDivisionReview else { return marketingTeams }
        return [
            .bundesliga2: [darmstadt, hannover], .dfbPokal: [darmstadt, bayern],
            .championship: [norwich, southampton], .faCup: [norwich, arsenal],
            .carabaoCup: [norwich, chelsea],
            .laLiga2: [almeria, granada], .copaDelRey: [almeria, realMadrid],
            .serieB: [palermo, sampdoria], .coppaItalia: [palermo, juventus],
            .ligue2: [saintEtienne, reims], .coupeDeFrance: [saintEtienne, psg],
            // Fictional qualification scenarios exercise every supported separate feed.
            .bundesligaPlayoff: [darmstadt, bayern], .bundesliga2Playoff: [hannover, darmstadt],
            .ligue1Playoff: [saintEtienne, psg], .ligue2Playoff: [reims, saintEtienne],
            .clubFriendlies: [darmstadt, norwich], .europaLeague: [palermo, realMadrid],
            .conferenceLeague: [saintEtienne, arsenal]
        ]
    }

    // Representative US demo listings, not assertions of actual broadcast rights for these fictional fixtures.
    static func broadcasts(for league: League) -> [String] {
        switch league {
        case .epl: return ["NBC", "Peacock"]
        case .championsLeague, .serieA: return ["Paramount+"]
        case .mls: return ["MLS Season Pass"]
        default: return ["ESPN+"]
        }
    }

    static func events(league: League, teamId: String? = nil) -> [ESPNEvent] {
        guard let clubs = teams[league], clubs.count >= 2 else { return [] }
        if let teamId, !clubs.contains(where: { $0.id == teamId }) { return [] }
        // Keep fixture ordering stable across appearances and make each competition
        // visibly distinct in the marketing crop (league +5, cup +10, UCL +15).
        let dayOffset: Int
        switch league {
        case .epl, .laLiga, .bundesliga, .serieA, .ligue1, .mls,
             .championship, .laLiga2, .bundesliga2, .serieB, .ligue2: dayOffset = 5
        case .faCup, .copaDelRey, .dfbPokal, .coppaItalia, .coupeDeFrance: dayOffset = 10
        case .championsLeague, .concacafChampionsCup, .leaguesCup: dayOffset = 15
        default: dayOffset = 20
        }
        // A fuller Premier League schedule lets the native list show broadcast details
        // without leaving the club artwork halfway beneath the navigation bar.
        return (league == .epl ? [0, 14, 21, 28, 35, 42, 49] : [0]).enumerated().map { index, extraDays in
            let date = ISO8601DateFormatter().string(from: referenceDate.addingTimeInterval(Double(dayOffset + extraDays) * 86400 + 19 * 3600))
            let away = clubs[(index % (clubs.count - 1)) + 1]
            let id = "screenshot-match-" + league.slug + (index == 0 ? "" : "-\(index)")
            let reviewVenues = ["381": "Carrow Road", "3812": "Böllenfalltor", "6832": "Estadio de los Juegos Mediterráneos",
                                "2923": "Stadio Renzo Barbera", "178": "Stade Geoffroy-Guichard"]
            let venue = isSecondDivisionReview ? reviewVenues[clubs[0].id.replacingOccurrences(of: "review-", with: "")] : nil
            return ESPNEvent(id: id, date: date, name: "\(clubs[0].name!) vs. \(away.name!)",
                shortName: nil, status: ESPNStatus(type: ESPNStatusType(id: nil, name: "STATUS_SCHEDULED", state: "pre", completed: false, detail: nil)),
                competitions: [ESPNCompetition(id: id, date: date,
                    venue: ESPNVenue(fullName: venue ?? (league == .mls ? "BMO Stadium" : "Old Trafford"), address: nil),
                    competitors: [ESPNCompetitor(id: clubs[0].id, homeAway: "home", team: clubs[0]),
                                  ESPNCompetitor(id: away.id, homeAway: "away", team: away)],
                    broadcasts: [ESPNBroadcast(names: broadcasts(for: league))])])
        }
    }

    static func populate(context: ModelContext, empty: Bool? = nil, scenario: MockReviewScenario? = nil) {
        let scenario = scenario ?? launchScenario
        guard !(empty ?? (isEmpty || scenario == .empty)), (try? context.fetchCount(FetchDescriptor<TrackedTeam>())) == 0 else { return }
        if isCapturing {
            for club in teams.values.flatMap({ $0 }) {
                precondition(artwork(for: club.logos?.first?.href) != nil, "Missing real catalog artwork for \(club.name ?? club.id)")
            }
        }
        // Keep Manchester United in several competitions so the Following screen
        // demonstrates one club with multiple tracked schedules.
        let follows: [(ESPNTeam, League)] = isSecondDivisionReview ? [
            (darmstadt, .bundesliga2), (darmstadt, .dfbPokal),
            (norwich, .championship), (almeria, .laLiga2),
            (palermo, .serieB), (saintEtienne, .ligue2)
        ] : [
            (united, .epl), (united, .faCup), (united, .championsLeague),
            (realMadrid, .laLiga), (realMadrid, .copaDelRey), (realMadrid, .championsLeague),
            (bayern, .bundesliga), (bayern, .dfbPokal), (bayern, .championsLeague),
            (juventus, .serieA), (juventus, .coppaItalia), (juventus, .championsLeague),
            (psg, .ligue1), (psg, .coupeDeFrance), (psg, .championsLeague),
            (lafc, .mls), (lafc, .concacafChampionsCup), (lafc, .leaguesCup)
        ]
        for (index, follow) in follows.enumerated() {
            let (club, league) = follow
            if isCapturing {
                precondition(artwork(for: club.logos?.first?.href) != nil, "Missing bundled mock artwork for \(club.name ?? club.id)")
            }
            let followed = TrackedTeam(espnId: club.id, leagueSlug: league.slug, name: club.name!,
                shortDisplayName: club.name, abbreviation: club.abbreviation,
                logoURL: club.logos?.first?.href, primaryColor: club.color)
            followed.addedAt = referenceDate.addingTimeInterval(Double(-index))
            context.insert(followed)
            for event in events(league: league) {
                let match = event.competitions[0]
                context.insert(TrackedGame(espnEventId: event.id, followedTeamId: club.id, leagueSlug: league.slug,
                    homeTeamName: match.competitors[0].team.name!, homeTeamLogo: match.competitors[0].team.logos?.first?.href,
                    awayTeamName: match.competitors[1].team.name!, awayTeamLogo: match.competitors[1].team.logos?.first?.href,
                    kickoff: ISO8601DateFormatter().date(from: event.date)!, venue: match.venue?.fullName,
                    broadcasts: broadcasts(for: league), status: "STATUS_SCHEDULED"))
            }
        }
        let games = (try? context.fetch(FetchDescriptor<TrackedGame>())) ?? []
        switch scenario {
        case .typical, .empty:
            break
        case .datesPending:
            // A partially known fixture remains visible while its provider data is repaired.
            for game in games.prefix(3) {
                game.venue = nil
                game.broadcasts = []
                game.missingSince = referenceDate
            }
        case .syncFailure:
            // Keep existing fixtures visible while marking their calendar writes as pending.
            for game in games.prefix(3) {
                game.calendarEventId = nil
                game.calendarSyncPending = true
            }
        case .longTitles:
            let longName = "Association Sportive de la Ville de Manchester United Supporters Club"
            for team in (try? context.fetch(FetchDescriptor<TrackedTeam>())) ?? [] {
                team.name = longName
                team.shortDisplayName = longName
            }
            for game in games.prefix(3) {
                game.homeTeamName = longName
                game.awayTeamName = "Club Atlético de Madrid International Development XI"
            }
        }
        try? context.save()
    }
}
#endif
