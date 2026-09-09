import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Binding var leagueFilter: League?

    @EnvironmentObject var espn: ESPNService
    @EnvironmentObject var teamManager: TeamManager
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var notifications: NotificationService
    @Environment(\.modelContext) private var context
    @Query private var followed: [TrackedTeam]

    @State private var teamsByLeague: [League: [ESPNTeam]] = [:]
    @State private var isLoading = false
    @State private var query = ""
    @State private var addingIds: Set<String> = []
    @State private var pendingRemoval: TrackedTeam?

    private var leaguesToShow: [League] {
        if let l = leagueFilter { return [l] }
        return League.allCases
    }

    var body: some View {
        List {
            ForEach(visibleLeagues) { league in
                Section(league.displayName) {
                    ForEach(filteredTeams(for: league), id: \.id) { team in
                        NavigationLink {
                            TeamDetailView(espnTeam: team, league: league)
                        } label: {
                            FeedRow(
                                logoURL: team.logos?.first?.href,
                                fallbackIcon: "sportscourt",
                                title: team.displayName ?? team.name ?? "Unknown"
                            ) {
                                Text(league.shortName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } trailing: {
                                if addingIds.contains(team.id) {
                                    ProgressView()
                                } else if isFollowed(team, league: league) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel("Following")
                                }
                            }
                        }
                        .swipeActions(allowsFullSwipe: false) {
                            if isFollowed(team, league: league) {
                                Button(role: .destructive) {
                                    pendingRemoval = followed.first {
                                        $0.espnId == team.id && $0.leagueSlug == league.slug
                                    }
                                } label: {
                                    Label("Unfollow", systemImage: "minus.circle")
                                }
                            } else {
                                Button {
                                    Task { await follow(team, league: league) }
                                } label: {
                                    Label("Follow", systemImage: "plus.circle")
                                }
                                .tint(.accentColor)
                                .disabled(addingIds.contains(team.id))
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if isLoading && teamsByLeague.isEmpty {
                ProgressView("Loading teams…")
            } else if visibleLeagues.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView("No teams available", systemImage: "sportscourt", description: Text("Choose another competition or try again later."))
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .navigationTitle("Discover")
        .searchable(text: $query, prompt: "Search teams")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CompetitionFilterMenu(selection: $leagueFilter)
            }
        }
        .confirmationDialog(
            "Unfollow \(pendingRemoval?.name ?? "team")?",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Unfollow", role: .destructive) {
                if let team = pendingRemoval {
                    teamManager.unfollow(team: team, context: context, calendar: calendar, notifications: notifications)
                }
                pendingRemoval = nil
            }
        } message: {
            Text("This removes the team's fixtures for this competition from your calendar.")
        }
        .task(id: leagueFilter) { await load() }
    }

    private var visibleLeagues: [League] {
        leaguesToShow.filter { !filteredTeams(for: $0).isEmpty }
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

    private func follow(_ team: ESPNTeam, league: League) async {
        addingIds.insert(team.id)
        await teamManager.follow(
            espnTeam: team,
            league: league,
            context: context,
            espn: espn,
            calendar: calendar,
            notifications: notifications
        )
        addingIds.remove(team.id)
    }

}
