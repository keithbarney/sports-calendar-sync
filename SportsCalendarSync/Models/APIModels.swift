import Foundation

// MARK: - ESPN /teams response

struct ESPNTeamsResponse: Decodable {
    let sports: [ESPNSport]
}

struct ESPNSport: Decodable {
    let leagues: [ESPNLeague]
}

struct ESPNLeague: Decodable {
    let teams: [ESPNTeamWrapper]
}

struct ESPNTeamWrapper: Decodable {
    let team: ESPNTeam
}

struct ESPNTeam: Decodable {
    let id: String
    let name: String?
    let displayName: String?
    let shortDisplayName: String?
    let abbreviation: String?
    let color: String?
    let logos: [ESPNLogo]?
}

struct ESPNLogo: Decodable {
    let href: String
}

// MARK: - ESPN /schedule + /scoreboard responses

struct ESPNScheduleResponse: Decodable {
    let events: [ESPNEvent]?
    let team: ESPNTeam?
}

struct ESPNScoreboardResponse: Decodable {
    let events: [ESPNEvent]
}

struct ESPNEvent: Decodable {
    let id: String
    let date: String // ISO8601
    let name: String
    let shortName: String?
    let status: ESPNStatus?
    let competitions: [ESPNCompetition]
}

struct ESPNStatus: Decodable {
    let type: ESPNStatusType?
}

struct ESPNStatusType: Decodable {
    let id: String?
    let name: String? // "STATUS_SCHEDULED", etc.
    let state: String?
    let completed: Bool?
    let detail: String?
}

struct ESPNCompetition: Decodable {
    let id: String
    let date: String
    let venue: ESPNVenue?
    let competitors: [ESPNCompetitor]
    let broadcasts: [ESPNBroadcast]?
}

struct ESPNVenue: Decodable {
    let fullName: String?
    let address: ESPNAddress?
}

struct ESPNAddress: Decodable {
    let city: String?
    let country: String?
}

struct ESPNCompetitor: Decodable {
    let id: String
    let homeAway: String // "home" | "away"
    let team: ESPNTeam
    let score: String?
}

struct ESPNBroadcast: Decodable {
    let market: String?
    let names: [String]?
}
