import Foundation
import SwiftUI

enum League: String, CaseIterable, Identifiable, Codable {
    case mls        = "usa.1"
    case epl        = "eng.1"
    case laLiga     = "esp.1"
    case bundesliga = "ger.1"
    case serieA     = "ita.1"
    case ligue1     = "fra.1"

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
        }
    }
}
