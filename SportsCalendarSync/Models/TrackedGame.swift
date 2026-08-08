import Foundation
import SwiftData

@Model
final class TrackedGame {
    /// ESPN event id.
    var espnEventId: String
    /// ESPN team id of the followed team (owner of this tracked entry).
    var followedTeamId: String
    var leagueSlug: String

    var homeTeamName: String
    var homeTeamLogo: String?
    var awayTeamName: String
    var awayTeamLogo: String?

    var kickoff: Date
    var venue: String?
    var broadcasts: [String]
    var status: String? // "STATUS_SCHEDULED", "STATUS_POSTPONED", "STATUS_FINAL", ...

    /// EventKit identifier for the mirrored calendar event.
    var calendarEventId: String?
    /// True when local fixture data is newer than the mirrored EventKit event.
    var calendarSyncPending: Bool = false
    var addedAt: Date
    var lastUpdated: Date
    /// First complete refresh where ESPN no longer returned this fixture.
    /// A grace period prevents transient API omissions from deleting valid events.
    var missingSince: Date?

    init(
        espnEventId: String,
        followedTeamId: String,
        leagueSlug: String,
        homeTeamName: String,
        homeTeamLogo: String? = nil,
        awayTeamName: String,
        awayTeamLogo: String? = nil,
        kickoff: Date,
        venue: String? = nil,
        broadcasts: [String] = [],
        status: String? = nil
    ) {
        self.espnEventId = espnEventId
        self.followedTeamId = followedTeamId
        self.leagueSlug = leagueSlug
        self.homeTeamName = homeTeamName
        self.homeTeamLogo = homeTeamLogo
        self.awayTeamName = awayTeamName
        self.awayTeamLogo = awayTeamLogo
        self.kickoff = kickoff
        self.venue = venue
        self.broadcasts = broadcasts
        self.status = status
        self.addedAt = Date()
        self.lastUpdated = Date()
        self.missingSince = nil
        self.calendarSyncPending = false
    }

    var title: String { "\(homeTeamName) vs. \(awayTeamName)" }
}
