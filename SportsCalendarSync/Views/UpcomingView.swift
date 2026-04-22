import SwiftUI
import SwiftData

/// First tab — lists all teams the user is following. Tap a team → `TeamDetailView` shows fixtures.
struct FollowingView: View {
    @Binding var leagueFilter: League?
    @Query(sort: \TrackedTeam.addedAt, order: .reverse) private var teams: [TrackedTeam]

    var visibleTeams: [TrackedTeam] {
        guard let leagueFilter else { return teams }
        return teams.filter { $0.leagueSlug == leagueFilter.slug }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if visibleTeams.isEmpty {
                    EmptyState(
                        icon: "star",
                        title: "Not following any teams",
                        message: "Go to Discover to find and follow your first team."
                    )
                    .padding(.top, 80)
                } else {
                    ForEach(visibleTeams) { team in
                        HiddenChevronNavigationLink {
                            TeamDetailView(team: team)
                        } label: {
                            FeedRow(
                                logoURL: team.logoURL,
                                fallbackIcon: "sparkles",
                                title: team.name
                            ) {
                                if let league = team.league {
                                    Text(league.displayName)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
    }
}
