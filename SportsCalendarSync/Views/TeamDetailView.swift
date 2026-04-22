import SwiftUI
import SwiftData

struct TeamDetailView: View {
    let team: TrackedTeam

    @EnvironmentObject var espn: ESPNService
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var teamManager: TeamManager
    @EnvironmentObject var toast: ToastManager
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var allGames: [TrackedGame]
    @State private var isRefreshing = false

    var fixtures: [TrackedGame] {
        let now = Date().addingTimeInterval(-3 * 60 * 60) // include in-progress
        return allGames
            .filter { $0.followedTeamId == team.espnId && $0.leagueSlug == team.leagueSlug }
            .filter { $0.kickoff >= now }
            .sorted { $0.kickoff < $1.kickoff }
    }

    var recent: [TrackedGame] {
        let now = Date()
        return allGames
            .filter { $0.followedTeamId == team.espnId && $0.leagueSlug == team.leagueSlug }
            .filter { $0.kickoff < now }
            .sorted { $0.kickoff > $1.kickoff }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if !teamManager.lastSyncSummary.isEmpty {
                    Text(teamManager.lastSyncSummary)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

                section(title: "Upcoming fixtures (\(fixtures.count))") {
                    if fixtures.isEmpty {
                        Text(isRefreshing ? "Loading…" : "No upcoming fixtures.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    } else {
                        ForEach(fixtures) { game in
                            FixtureRow(game: game)
                        }
                    }
                }

                if !recent.isEmpty {
                    section(title: "Recent") {
                        ForEach(recent) { game in
                            FixtureRow(game: game).opacity(0.6)
                        }
                    }
                }

                Button(role: .destructive) {
                    teamManager.unfollow(team: team, context: context, calendar: calendar)
                    toast.show("Unfollowed \(team.name)", style: .success)
                    dismiss()
                } label: {
                    Text("Unfollow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.top, 12)
            }
            .padding(16)
            .padding(.bottom, 100)
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            AsyncImage(url: team.logoURL.flatMap(URL.init(string:))) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                Circle().fill(.quaternary)
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(team.name).font(.system(size: 22, weight: .bold))
                if let league = team.league {
                    Text(league.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(league.accent.opacity(0.2), in: Capsule())
                        .foregroundStyle(league.accent)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func refresh() async {
        guard let league = team.league else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await teamManager.syncSchedule(
            for: team,
            context: context,
            espn: espn,
            calendar: calendar,
            league: league
        )
    }
}

struct FixtureRow: View {
    let game: TrackedGame

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(game.title)
                .font(.system(size: 15, weight: .semibold))
            HStack(spacing: 8) {
                Text(kickoffLabel)
                if let venue = game.venue {
                    Text("·").foregroundStyle(.tertiary)
                    Text(venue).lineLimit(1)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            if !game.broadcasts.isEmpty {
                Text(game.broadcasts.joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var kickoffLabel: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: game.kickoff)
    }
}
