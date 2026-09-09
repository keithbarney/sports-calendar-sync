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

    var id: String { rawValue }

    /// ESPN URL slug used in all endpoints: `.../soccer/{slug}/...`
    var slug: String { rawValue }

    var displayName: String {
        switch self {
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

    /// Competitions currently confirmed for the men's first teams requested by the user.
    /// The source competition remains included so this can be used from Discover or a team detail screen.
    static func recommendedCompetitions(forTeamNamed name: String) -> [Competition] {
        let normalized = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        if normalized.contains("manchesterunited") || normalized.contains("manutd") {
            return [.epl, .championsLeague, .faCup, .carabaoCup]
        }
        if normalized.contains("lafc") || normalized.contains("losangelesfc") {
            return [.mls, .concacafChampionsCup, .leaguesCup]
        }
        return []
    }
}

/// Kept as a source-compatible alias while persisted properties and older tests migrate from
/// the original league-only naming. New code should use `Competition`.
typealias League = Competition
