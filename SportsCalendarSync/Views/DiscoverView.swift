import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Binding var leagueFilter: League?

    @EnvironmentObject var espn: ESPNService
    @EnvironmentObject var teamManager: TeamManager
    @EnvironmentObject var calendar: CalendarService
    @Environment(\.modelContext) private var context
    @Query private var followed: [TrackedTeam]

    @State private var teamsByLeague: [League: [ESPNTeam]] = [:]
    @State private var isLoading = false
    @State private var query = ""

    var leaguesToShow: [League] {
        if let l = leagueFilter { return [l] }
        return League.allCases
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SegmentedFilter(selected: $leagueFilter)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        SearchBarStub(text: $query)
                            .padding(.horizontal, 16)

                    ForEach(leaguesToShow) { league in
                        let teams = filteredTeams(for: league)
                        if !teams.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(league.displayName)
                                        .font(.system(size: 17, weight: .semibold))
                                    Spacer()
                                }
                                .padding(.horizontal, 16)

                                ForEach(teams, id: \.id) { t in
                                    TeamRow(team: t, league: league, isFollowed: isFollowed(t, league: league)) {
                                        await toggleFollow(t, league: league)
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Discover")
            .toolbar(.hidden, for: .navigationBar)
            .task(id: leagueFilter) { await load() }
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        for league in leaguesToShow where teamsByLeague[league] == nil {
            if let teams = try? await espn.getTeams(league: league) {
                teamsByLeague[league] = teams.sorted {
                    ($0.displayName ?? "") < ($1.displayName ?? "")
                }
            }
        }
    }

    private func filteredTeams(for league: League) -> [ESPNTeam] {
        let all = teamsByLeague[league] ?? []
        guard !query.isEmpty else { return all }
        return all.filter { ($0.displayName ?? "").localizedCaseInsensitiveContains(query) }
    }

    private func isFollowed(_ team: ESPNTeam, league: League) -> Bool {
        followed.contains(where: { $0.espnId == team.id && $0.leagueSlug == league.slug })
    }

    private func toggleFollow(_ team: ESPNTeam, league: League) async {
        if let existing = followed.first(where: { $0.espnId == team.id && $0.leagueSlug == league.slug }) {
            teamManager.unfollow(team: existing, context: context, calendar: calendar)
        } else {
            await teamManager.follow(espnTeam: team, league: league, context: context, espn: espn, calendar: calendar)
        }
    }
}

struct TeamRow: View {
    let team: ESPNTeam
    let league: League
    let isFollowed: Bool
    let onToggle: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: team.logos?.first.map { URL(string: $0.href) } ?? nil) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                Circle().fill(.quaternary)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(team.displayName ?? team.name ?? "Unknown")
                    .font(.system(size: 15, weight: .semibold))
                Text(league.shortName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await onToggle() }
            } label: {
                Image(systemName: isFollowed ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isFollowed ? Color.green : Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SearchBarStub: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search teams", text: $text)
                .textInputAutocapitalization(.words)
        }
        .padding(10)
        .background(.thinMaterial, in: Capsule())
    }
}
