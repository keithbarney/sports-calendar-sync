import SwiftUI
import SwiftData

/// Crest-first detail layout for a followed team.
/// Sports equivalent of ShowSync's `DetailTemplate` — no hero backdrop, big crest + chips + fixtures.
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
    @State private var didInitialLoad = false

    private var fixtures: [TrackedGame] {
        let now = Date().addingTimeInterval(-3 * 60 * 60) // include in-progress
        return allGames
            .filter { $0.followedTeamId == team.espnId && $0.leagueSlug == team.leagueSlug }
            .filter { $0.kickoff >= now }
            .sorted { $0.kickoff < $1.kickoff }
    }

    private var recent: [TrackedGame] {
        let now = Date()
        return allGames
            .filter { $0.followedTeamId == team.espnId && $0.leagueSlug == team.leagueSlug }
            .filter { $0.kickoff < now }
            .sorted { $0.kickoff > $1.kickoff }
            .prefix(5)
            .map { $0 }
    }

    private var chips: [ChipData] {
        var result: [ChipData] = []
        if let league = team.league {
            result.append(ChipData(label: league.displayName, color: league.accent))
        }
        if let abbr = team.abbreviation {
            result.append(ChipData(label: abbr, color: .textSecondary))
        }
        return result
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    crestHeader

                    VStack(alignment: .leading, spacing: 32) {
                        Text(team.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.textPrimary)

                        if !chips.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(chips) { chip in
                                    DetailChip(label: chip.label, icon: chip.icon, color: chip.color)
                                }
                            }
                        }

                        statsSection

                        fixturesSection

                        if !recent.isEmpty {
                            recentSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
            }

            ActionButton(
                isTracked: true,
                isAdding: false,
                removeTitle: team.name,
                addLabel: "Follow Team",
                addedLabel: "Following",
                removeLabel: "Unfollow",
                confirmationMessage: "This will unfollow the team and remove all of its fixtures from your calendar.",
                onAdd: {},
                onRemove: {
                    teamManager.unfollow(team: team, context: context, calendar: calendar)
                    toast.show("Unfollowed \(team.name)", icon: "minus.circle.fill", isDestructive: true)
                    dismiss()
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.background)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .topLeading) { backButton }
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            await refresh()
        }
        .refreshable { await refresh() }
    }

    // MARK: - Crest Header

    private var crestHeader: some View {
        ZStack {
            Rectangle()
                .fill(Color.surfaceElevated)
                .frame(height: 240)

            VStack(spacing: 12) {
                CrestView(url: team.logoURL, size: 120, fallbackIcon: "sparkles")
                    .background(
                        Circle()
                            .fill(Color.surface)
                            .frame(width: 140, height: 140)
                    )
            }
            .padding(.top, 40)
        }
        .frame(height: 240)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 0) {
            StatBox(value: "\(fixtures.count)", label: "Upcoming")
            StatBox(value: "\(recent.count)", label: "Recent")
            StatBox(value: team.league?.shortName ?? "—", label: "League")
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Fixtures

    private var fixturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UPCOMING FIXTURES").sectionHeader()
            if fixtures.isEmpty {
                Text(isRefreshing ? "Loading…" : "No upcoming fixtures.")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 2) {
                    ForEach(fixtures) { game in
                        FixtureRow(game: game)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT").sectionHeader()
            VStack(spacing: 2) {
                ForEach(recent) { game in
                    FixtureRow(game: game).opacity(0.6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Back button (capsule glass)

    private var backButton: some View {
        Button { dismiss() } label: {
            HStack(spacing: 4) {
                LucideIcon(name: "chevron-left", size: 16)
                Text("Back").font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 36)
        }
        .capsuleGlass(interactive: true)
        .padding(.leading, 16)
        .padding(.top, 54)
    }

    // MARK: - Data

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

// MARK: - Fixture Row

struct FixtureRow: View {
    let game: TrackedGame

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(game.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.textPrimary)
            HStack(spacing: 8) {
                Text(kickoffLabel)
                if let venue = game.venue {
                    Text("·").foregroundStyle(.textTertiary)
                    Text(venue).lineLimit(1)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.textSecondary)

            if !game.broadcasts.isEmpty {
                Text(game.broadcasts.joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundStyle(.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.surface)
    }

    private var kickoffLabel: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: game.kickoff)
    }
}
