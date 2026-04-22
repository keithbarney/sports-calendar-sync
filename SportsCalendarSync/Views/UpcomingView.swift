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
        NavigationStack {
            VStack(spacing: 0) {
                SegmentedFilter(selected: $leagueFilter)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if visibleTeams.isEmpty {
                            Text("Not following any teams yet.\nGo to Discover to follow your first team.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.top, 80)
                        } else {
                            ForEach(visibleTeams) { team in
                                NavigationLink(destination: TeamDetailView(team: team)) {
                                    FollowingRow(team: team)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Following")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct FollowingRow: View {
    let team: TrackedTeam

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: team.logoURL.flatMap(URL.init(string:))) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                Circle().fill(.quaternary)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(.system(size: 15, weight: .semibold))
                if let league = team.league {
                    Text(league.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

typealias UpcomingView = FollowingView
