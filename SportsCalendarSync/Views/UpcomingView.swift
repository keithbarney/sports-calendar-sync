import SwiftUI
import SwiftData

/// First tab — lists all teams the user is following. Tap a team → `TeamDetailView` shows fixtures.
struct FollowingView: View {
    @Binding var leagueFilter: League?
    @EnvironmentObject private var userSurvey: UserSurveyStore
    @Query(sort: \TrackedTeam.addedAt, order: .reverse) private var teams: [TrackedTeam]
    @Query private var games: [TrackedGame]

    private struct FollowedClub: Identifiable {
        let id: String
        let team: TrackedTeam
        let competitions: [Competition]
    }

    var visibleTeams: [TrackedTeam] {
        guard let leagueFilter else { return teams }
        return teams.filter { $0.leagueSlug == leagueFilter.slug }
    }

    private var visibleClubs: [FollowedClub] {
        Dictionary(grouping: visibleTeams, by: clubKey(for:))
            .compactMap { key, teams in
                guard let team = teams.max(by: { $0.addedAt < $1.addedAt }) else { return nil }
                let competitions = teams.compactMap(\.competition).sorted { $0.displayName < $1.displayName }
                return FollowedClub(id: key, team: team, competitions: competitions)
            }
            .sorted { $0.team.addedAt > $1.team.addedAt }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            followingList(at: timeline.date)
        }
        .navigationTitle("Following")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CompetitionFilterMenu(selection: $leagueFilter)
            }
        }
    }

    private func followingList(at now: Date) -> some View {
        let nextFixtures = FollowingFixtureSummary.nextByClub(teams: teams, games: games, now: now)
        return List {
            ForEach(visibleClubs) { club in
                NavigationLink(value: club.team) {
                    FeedRow(
                        logoURL: club.team.logoURL,
                        fallbackIcon: "sportscourt",
                        title: club.team.name
                    ) {
                        Text(club.competitions.map(\.shortName).joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let fixture = nextFixtures[club.id] {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Next: \(fixture.matchup)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("\(fixture.kickoff.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())) · \(fixture.competition)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        } else {
                            Text("No upcoming fixtures")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("following-club-\(club.id)")
            }
            Section { UserSurveyInvitationCard() }
        }
        .overlay {
            if visibleClubs.isEmpty && !userSurvey.shouldInvite {
                ContentUnavailableView(
                    leagueFilter == nil ? "No followed teams" : "No teams in this competition",
                    systemImage: "calendar.badge.plus",
                    description: Text("Find teams in Discover or choose another competition.")
                )
            }
        }
        .modifier(ReadableListLayout())
    }

    private func clubKey(for team: TrackedTeam) -> String {
        ESPNTeam.clubNameKey(team.name)
    }
}
