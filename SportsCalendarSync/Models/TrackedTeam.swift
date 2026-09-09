import Foundation
import SwiftData

@Model
final class TrackedTeam {
    /// ESPN team id (string in some endpoints, numeric in others — normalized to string here).
    var espnId: String
    /// Competition slug, e.g. `eng.1` or `uefa.champions`.
    var leagueSlug: String
    var name: String
    var shortDisplayName: String?
    var abbreviation: String?
    var logoURL: String?
    var primaryColor: String?
    var addedAt: Date
    var lastUpdated: Date

    init(
        espnId: String,
        leagueSlug: String,
        name: String,
        shortDisplayName: String? = nil,
        abbreviation: String? = nil,
        logoURL: String? = nil,
        primaryColor: String? = nil
    ) {
        self.espnId = espnId
        self.leagueSlug = leagueSlug
        self.name = name
        self.shortDisplayName = shortDisplayName
        self.abbreviation = abbreviation
        self.logoURL = logoURL
        self.primaryColor = primaryColor
        self.addedAt = Date()
        self.lastUpdated = Date()
    }

    var competition: Competition? { Competition(rawValue: leagueSlug) }

    /// Compatibility alias for views and persisted data that still use the old league naming.
    var league: League? { competition }
}
