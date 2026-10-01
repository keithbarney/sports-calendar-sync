import Foundation
import Combine

@MainActor
final class DiscoveryCatalog: ObservableObject {
    @Published private(set) var teamsByCompetition: [Competition: [ESPNTeam]] = [:]
    @Published private(set) var loading: Set<Competition> = []
    @Published private(set) var failed: Set<Competition> = []
    @Published private(set) var isLoading = false

    var teams: [DiscoveryTeam] { DiscoveryTeam.uniqueTeams(in: teamsByCompetition) }
    var popular: [DiscoveryTeam] { PopularTeams.select(from: teams) }

    func loadAll(using espn: ESPNService) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        for competition in DiscoveryTeam.competitionOrder {
            guard !Task.isCancelled else { return }
            await load(competition, using: espn)
        }
    }

    func load(_ competition: Competition, using espn: ESPNService) async {
        guard teamsByCompetition[competition] == nil, !loading.contains(competition) else { return }
        loading.insert(competition)
        defer { loading.remove(competition) }
        do {
            let teams = try await espn.getTeams(league: competition)
            try Task.checkCancellation()
            teamsByCompetition[competition] = teams.sorted {
                ($0.displayName ?? $0.name ?? "").localizedStandardCompare($1.displayName ?? $1.name ?? "") == .orderedAscending
            }
            failed.remove(competition)
        } catch {
            if !Task.isCancelled { failed.insert(competition) }
        }
    }
}
