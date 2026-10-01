import Foundation
import SwiftUI

enum Competition: String, CaseIterable, Identifiable, Codable, Hashable {
    case mls        = "usa.1"
    case epl        = "eng.1"
    case laLiga     = "esp.1"
    case bundesliga = "ger.1"
    case serieA     = "ita.1"
    case ligue1     = "fra.1"
    case championsLeague       = "uefa.champions"
    case faCup                 = "eng.fa"
    case carabaoCup            = "eng.league_cup"
    case concacafChampionsCup  = "concacaf.champions"
    case leaguesCup            = "concacaf.leagues.cup"

    case europaLeague = "uefa.europa"
    case conferenceLeague = "uefa.europa.conf"
    case copaDelRey = "esp.copa_del_rey"
    case spanishSuperCup = "esp.super_cup"
    case dfbPokal = "ger.dfb_pokal"
    case germanSuperCup = "ger.super_cup"
    case coppaItalia = "ita.coppa_italia"
    case italianSuperCup = "ita.super_cup"
    case coupeDeFrance = "fra.coupe_de_france"
    case tropheeDesChampions = "fra.super_cup"
    case communityShield = "eng.charity"
    case uefaSuperCup = "uefa.super_cup"
    case usOpenCup = "usa.open"
    case clubWorldCup = "fifa.cwc"
    case intercontinentalCup = "fifa.intercontinental_cup"

    // Second tiers and separate postseason/schedule feeds. Other domestic and UEFA
    // cups are shared with first-tier clubs; membership is resolved from ESPN.
    case championship = "eng.2"
    case laLiga2 = "esp.2"
    case bundesliga2 = "ger.2"
    case serieB = "ita.2"
    case ligue2 = "fra.2"
    case bundesligaPlayoff = "ger.playoff.relegation"
    case bundesliga2Playoff = "ger.2.promotion.relegation"
    case ligue1Playoff = "fra.1.promotion.relegation"
    case ligue2Playoff = "fra.2.promotion.relegation"
    case clubFriendlies = "club.friendly"

    var id: String { rawValue }

    /// ESPN URL slug used in all endpoints: `.../soccer/{slug}/...`
    var slug: String { rawValue }

    var displayName: String {
        switch self {
        case .championship: return "EFL Championship"
        case .laLiga2: return "LaLiga 2"
        case .bundesliga2: return "2. Bundesliga"
        case .serieB: return "Serie B"
        case .ligue2: return "Ligue 2"
        case .bundesligaPlayoff: return "Bundesliga Promotion/Relegation Playoff"
        case .bundesliga2Playoff: return "2. Bundesliga Promotion/Relegation Playoff"
        case .ligue1Playoff: return "Ligue 1 Promotion/Relegation Playoffs"
        case .ligue2Playoff: return "Ligue 2 Promotion/Relegation Playoff"
        case .clubFriendlies: return "Club Friendlies"
        case .europaLeague: return "UEFA Europa League"
        case .conferenceLeague: return "UEFA Conference League"
        case .copaDelRey: return "Copa del Rey"
        case .spanishSuperCup: return "Supercopa de España"
        case .dfbPokal: return "DFB-Pokal"
        case .germanSuperCup: return "German Supercup"
        case .coppaItalia: return "Coppa Italia"
        case .italianSuperCup: return "Supercoppa Italiana"
        case .coupeDeFrance: return "Coupe de France"
        case .tropheeDesChampions: return "Trophée des Champions"
        case .communityShield: return "FA Community Shield"
        case .uefaSuperCup: return "UEFA Super Cup"
        case .usOpenCup: return "U.S. Open Cup"
        case .clubWorldCup: return "FIFA Club World Cup"
        case .intercontinentalCup: return "FIFA Intercontinental Cup"
        case .mls:        return "MLS"
        case .epl:        return "Premier League"
        case .laLiga:     return "La Liga"
        case .bundesliga: return "Bundesliga"
        case .serieA:     return "Serie A"
        case .ligue1:     return "Ligue 1"
        case .championsLeague:      return "UEFA Champions League"
        case .faCup:                return "FA Cup"
        case .carabaoCup:           return "Carabao Cup"
        case .concacafChampionsCup: return "Concacaf Champions Cup"
        case .leaguesCup:           return "Leagues Cup"
        }
    }

    /// Short label used in chips and segmented filters.
    var shortName: String {
        switch self {
        case .championship: return "Championship"
        case .laLiga2: return "LaLiga 2"
        case .bundesliga2: return "2. Bundesliga"
        case .serieB: return "Serie B"
        case .ligue2: return "Ligue 2"
        case .bundesligaPlayoff: return "Bundesliga Playoff"
        case .bundesliga2Playoff: return "2. Bundesliga Playoff"
        case .ligue1Playoff: return "Ligue 1 Playoffs"
        case .ligue2Playoff: return "Ligue 2 Playoff"
        case .clubFriendlies: return "Friendlies"
        case .europaLeague: return "UEL"
        case .conferenceLeague: return "UECL"
        case .copaDelRey: return "Copa del Rey"
        case .spanishSuperCup: return "Supercopa"
        case .dfbPokal: return "DFB-Pokal"
        case .germanSuperCup: return "Supercup"
        case .coppaItalia: return "Coppa Italia"
        case .italianSuperCup: return "Supercoppa"
        case .coupeDeFrance: return "Coupe de France"
        case .tropheeDesChampions: return "Trophée"
        case .communityShield: return "Community Shield"
        case .uefaSuperCup: return "UEFA Super Cup"
        case .usOpenCup: return "U.S. Open Cup"
        case .clubWorldCup: return "Club World Cup"
        case .intercontinentalCup: return "Intercontinental"
        case .mls:        return "MLS"
        case .epl:        return "EPL"
        case .laLiga:     return "La Liga"
        case .bundesliga: return "Bundesliga"
        case .serieA:     return "Serie A"
        case .ligue1:     return "Ligue 1"
        case .championsLeague:      return "UCL"
        case .faCup:                return "FA Cup"
        case .carabaoCup:           return "Carabao"
        case .concacafChampionsCup: return "CCC"
        case .leaguesCup:           return "Leagues Cup"
        }
    }

    var country: String {
        switch self {
        case .championship: return "England"
        case .laLiga2: return "Spain"
        case .bundesliga2: return "Germany"
        case .serieB: return "Italy"
        case .ligue2: return "France"
        case .bundesligaPlayoff: return "Germany"
        case .bundesliga2Playoff: return "Germany"
        case .ligue1Playoff: return "France"
        case .ligue2Playoff: return "France"
        case .clubFriendlies: return "Worldwide"
        case .europaLeague: return "Europe"
        case .conferenceLeague: return "Europe"
        case .copaDelRey: return "Spain"
        case .spanishSuperCup: return "Spain"
        case .dfbPokal: return "Germany"
        case .germanSuperCup: return "Germany"
        case .coppaItalia: return "Italy"
        case .italianSuperCup: return "Italy"
        case .coupeDeFrance: return "France"
        case .tropheeDesChampions: return "France"
        case .communityShield: return "England"
        case .uefaSuperCup: return "Europe"
        case .usOpenCup: return "United States"
        case .clubWorldCup: return "Worldwide"
        case .intercontinentalCup: return "Worldwide"
        case .mls:        return "United States / Canada"
        case .epl:        return "England"
        case .laLiga:     return "Spain"
        case .bundesliga: return "Germany"
        case .serieA:     return "Italy"
        case .ligue1:     return "France"
        case .championsLeague:      return "Europe"
        case .faCup, .carabaoCup:   return "England"
        case .concacafChampionsCup: return "North America, Central America and the Caribbean"
        case .leaguesCup:           return "United States, Canada and Mexico"
        }
    }

    /// Placeholder accent color — wire up from Figma tokens later.
    var accent: Color {
        switch self {
        case .championship: return .purple
        case .laLiga2: return .orange
        case .bundesliga2: return .red
        case .serieB: return .blue
        case .ligue2: return .indigo
        case .bundesligaPlayoff: return .red
        case .bundesliga2Playoff: return .red
        case .ligue1Playoff: return .indigo
        case .ligue2Playoff: return .indigo
        case .clubFriendlies: return .blue
        case .europaLeague, .conferenceLeague, .copaDelRey, .spanishSuperCup,
             .dfbPokal, .germanSuperCup, .coppaItalia, .italianSuperCup,
             .coupeDeFrance, .tropheeDesChampions, .communityShield, .uefaSuperCup,
             .usOpenCup, .clubWorldCup, .intercontinentalCup:
            return .blue
        case .mls:        return .cyan
        case .epl:        return .purple
        case .laLiga:     return .orange
        case .bundesliga: return .red
        case .serieA:     return .blue
        case .ligue1:     return .indigo
        case .championsLeague:      return .yellow
        case .faCup:                return .green
        case .carabaoCup:           return .mint
        case .concacafChampionsCup: return .teal
        case .leaguesCup:           return .pink
        }
    }

    /// Keep saved follows editable even when a cup changes entrants or its feed fails.
    static func selectionOptions(source: Competition?, discovered: [Competition], followed: [Competition]) -> [Competition] {
        let available = Set(discovered + followed + [source].compactMap { $0 })
        return allCases.filter(available.contains)
    }
}

/// Kept as a source-compatible alias while persisted properties and older tests migrate from
/// the original league-only naming. New code should use `Competition`.
typealias League = Competition
