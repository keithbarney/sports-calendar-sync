import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Binding var leagueFilter: League?
    @Binding var isSearching: Bool

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
    @FocusState private var searchFocused: Bool

    private var leaguesToShow: [League] {
        if let l = leagueFilter { return [l] }
        return League.allCases
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                SearchBar(text: $query, placeholder: "Search teams…", isFocused: $searchFocused)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                if isLoading && teamsByLeague.isEmpty {
                    DiscoverSkeleton()
                        .padding(.top, 8)
                } else if visibleLeagues.isEmpty {
                    EmptyState(
                        icon: "search",
                        title: "No teams found",
                        message: query.isEmpty
                            ? "Pick a league above to browse teams."
                            : "Try a different search term."
                    )
                    .padding(.top, 80)
                } else {
                    ForEach(visibleLeagues) { league in
                        let teams = filteredTeams(for: league)
                        if !teams.isEmpty {
                            FeedSection(title: league.displayName) {
                                ForEach(teams, id: \.id) { t in
                                    HiddenChevronNavigationLink {
                                        TeamDetailView(espnTeam: t, league: league)
                                    } label: {
                                        FeedRow(
                                            logoURL: t.logos?.first?.href,
                                            fallbackIcon: "sparkles",
                                            title: t.displayName ?? t.name ?? "Unknown"
                                        ) {
                                            Text(league.shortName)
                                                .font(.system(size: 13))
                                                .foregroundStyle(.textSecondary)
                                        } trailing: {
                                            FeedRowActionButton(
                                                isTracked: isFollowed(t, league: league),
                                                isAdding: addingIds.contains(t.id),
                                                onAdd: { Task { await follow(t, league: league) } },
                                                onRemove: { unfollow(t, league: league) }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .task(id: leagueFilter) { await load() }
        .onChange(of: searchFocused) { _, focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                isSearching = focused
            }
        }
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

    private func unfollow(_ team: ESPNTeam, league: League) {
        guard let existing = followed.first(where: { $0.espnId == team.id && $0.leagueSlug == league.slug }) else { return }
        teamManager.unfollow(team: existing, context: context, calendar: calendar, notifications: notifications)
    }
}
