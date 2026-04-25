import SwiftUI
import SwiftData

/// Crest-first detail layout for a team. Works whether or not the team is followed —
/// mirrors the ID-based init pattern from TV & Movie Calendar Sync's `ShowDetailView`.
struct TeamDetailView: View {
    let espnId: String
    let leagueSlug: String
    let initialName: String
    let initialLogoURL: String?
    let initialPrimaryColor: String?
    let initialAbbreviation: String?

    @EnvironmentObject var espn: ESPNService
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var notifications: NotificationService
    @EnvironmentObject var teamManager: TeamManager
    @EnvironmentObject var toast: ToastManager
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var followedTeams: [TrackedTeam]
    @Query private var allGames: [TrackedGame]

    @State private var previewFixtures: [ESPNEvent] = []
    @State private var previewRecent: [ESPNEvent] = []
    @State private var isRefreshing = false
    @State private var isAdding = false
    @State private var didInitialLoad = false

    /// Convenience init for a team we already persisted.
    init(team: TrackedTeam) {
        self.espnId = team.espnId
        self.leagueSlug = team.leagueSlug
        self.initialName = team.name
        self.initialLogoURL = team.logoURL
        self.initialPrimaryColor = team.primaryColor
        self.initialAbbreviation = team.abbreviation
    }

    /// Init for a team pulled from search/Discover (not yet followed).
    init(espnTeam: ESPNTeam, league: League) {
        self.espnId = espnTeam.id
        self.leagueSlug = league.slug
        self.initialName = espnTeam.displayName ?? espnTeam.name ?? "Unknown"
        self.initialLogoURL = espnTeam.logos?.first?.href
        self.initialPrimaryColor = espnTeam.color
        self.initialAbbreviation = espnTeam.abbreviation
    }

    private var tracked: TrackedTeam? {
        followedTeams.first { $0.espnId == espnId && $0.leagueSlug == leagueSlug }
    }

    private var isFollowed: Bool { tracked != nil }

    private var league: League? { League(rawValue: leagueSlug) }

    private var displayName: String { tracked?.name ?? initialName }
    private var logoURL: String? { tracked?.logoURL ?? initialLogoURL }
    private var primaryColor: String? { tracked?.primaryColor ?? initialPrimaryColor }
    private var abbreviation: String? { tracked?.abbreviation ?? initialAbbreviation }

    /// Upcoming fixture count & list — uses stored TrackedGame if followed, else ESPN preview.
    private var fixtureCount: Int { isFollowed ? storedFixtures.count : previewFixtures.count }
    private var recentCount: Int { isFollowed ? storedRecent.count : previewRecent.count }

    private var storedFixtures: [TrackedGame] {
        let now = Date().addingTimeInterval(-3 * 60 * 60)
        return allGames
            .filter { $0.followedTeamId == espnId && $0.leagueSlug == leagueSlug }
            .filter { $0.kickoff >= now }
            .sorted { $0.kickoff < $1.kickoff }
    }

    private var storedRecent: [TrackedGame] {
        let now = Date()
        return allGames
            .filter { $0.followedTeamId == espnId && $0.leagueSlug == leagueSlug }
            .filter { $0.kickoff < now }
            .sorted { $0.kickoff > $1.kickoff }
            .prefix(5)
            .map { $0 }
    }

    private var chips: [ChipData] {
        var result: [ChipData] = []
        if let league {
            result.append(ChipData(label: league.displayName, color: league.accent))
        }
        if let abbr = abbreviation {
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
                        Text(displayName)
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

                        if recentCount > 0 {
                            recentSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
            }

            ActionButton(
                isTracked: isFollowed,
                isAdding: isAdding,
                removeTitle: displayName,
                addLabel: "Follow Team",
                addedLabel: "Following",
                removeLabel: "Unfollow",
                confirmationMessage: "This will unfollow the team and remove all of its fixtures from your calendar.",
                onAdd: { Task { await follow() } },
                onRemove: { unfollow() }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            titleBar
        }
        .background(Color.background)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            await refresh()
        }
        .refreshable { await refresh() }
    }

    // MARK: - Crest Header

    private var crestHeader: some View {
        let tint = Color(hex: primaryColor) ?? Color.surfaceElevated
        return ZStack {
            Rectangle()
                .fill(Color.surfaceElevated)

            RadialGradient(
                colors: [tint.opacity(0.85), tint.opacity(0.35), .clear],
                center: .center,
                startRadius: 40,
                endRadius: 520
            )
            .blur(radius: 60)

            VStack(spacing: 12) {
                CrestView(url: logoURL, size: 120, fallbackIcon: "sparkles")
            }
            .padding(.top, 40)
        }
        .frame(height: 240)
        .clipped()
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 0) {
            StatBox(value: "\(fixtureCount)", label: "Upcoming")
            StatBox(value: "\(recentCount)", label: "Recent")
            StatBox(value: league?.shortName ?? "—", label: "League")
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Fixtures

    @ViewBuilder
    private var fixturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UPCOMING FIXTURES").sectionHeader()
            if fixtureCount == 0 {
                Text(isRefreshing ? "Loading…" : "No upcoming fixtures.")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if isFollowed {
                VStack(spacing: 2) {
                    ForEach(storedFixtures) { game in
                        FixtureRow(game: game)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 2) {
                    ForEach(previewFixtures, id: \.id) { event in
                        PreviewFixtureRow(event: event, espn: espn)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT").sectionHeader()
            if isFollowed {
                VStack(spacing: 2) {
                    ForEach(storedRecent) { game in
                        FixtureRow(game: game).opacity(0.6)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 2) {
                    ForEach(previewRecent, id: \.id) { event in
                        PreviewFixtureRow(event: event, espn: espn).opacity(0.6)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Title Bar (back button — matches TV & Movie Calendar Sync)

    private var titleBar: some View {
        VStack(spacing: 0) {
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                LucideIcon(name: "chevron-left", size: 20)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .modifier(CircleGlassBackButton())
            }
            .padding(.leading, 16)
            .padding(.top, 54)
        }
    }

    // MARK: - Data

    private func refresh() async {
        guard let league else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if let tracked {
            await teamManager.syncSchedule(
                for: tracked,
                context: context,
                espn: espn,
                calendar: calendar,
                league: league,
                notifications: notifications
            )
        } else {
            // Unfollowed — fetch a preview directly without persisting.
            async let futureTask = try? espn.getUpcomingFixtures(league: league, teamId: espnId)
            async let pastTask = try? espn.getSchedule(league: league, teamId: espnId, useCache: false)
            let future = await futureTask ?? []
            let past = await pastTask ?? []
            let now = Date()
            previewFixtures = future
                .compactMap { evt in (espn.parseDate(evt.date).map { ($0, evt) }) }
                .filter { $0.0 >= now.addingTimeInterval(-3 * 60 * 60) }
                .sorted { $0.0 < $1.0 }
                .map { $0.1 }
            previewRecent = past
                .compactMap { evt in (espn.parseDate(evt.date).map { ($0, evt) }) }
                .filter { $0.0 < now }
                .sorted { $0.0 > $1.0 }
                .prefix(5)
                .map { $0.1 }
        }
    }

    private func follow() async {
        guard let league else { return }
        isAdding = true
        defer { isAdding = false }
        let espnTeam = ESPNTeam(
            id: espnId,
            name: initialName,
            displayName: initialName,
            shortDisplayName: nil,
            abbreviation: initialAbbreviation,
            color: initialPrimaryColor,
            logos: initialLogoURL.map { [ESPNLogo(href: $0)] }
        )
        await teamManager.follow(
            espnTeam: espnTeam,
            league: league,
            context: context,
            espn: espn,
            calendar: calendar,
            notifications: notifications
        )
        toast.show("Following \(displayName)", icon: "checkmark.circle.fill", isDestructive: false)
    }

    private func unfollow() {
        guard let tracked else { return }
        teamManager.unfollow(team: tracked, context: context, calendar: calendar, notifications: notifications)
        toast.show("Unfollowed \(displayName)", icon: "minus.circle.fill", isDestructive: true)
        dismiss()
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

// MARK: - Preview Fixture Row (unfollowed teams — not yet persisted)

private struct PreviewFixtureRow: View {
    let event: ESPNEvent
    let espn: ESPNService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.textPrimary)
            HStack(spacing: 8) {
                Text(kickoffLabel)
                if let venue = event.competitions.first?.venue?.fullName {
                    Text("·").foregroundStyle(.textTertiary)
                    Text(venue).lineLimit(1)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.textSecondary)

            if let broadcasts = event.competitions.first?.broadcasts?.flatMap({ $0.names ?? [] }), !broadcasts.isEmpty {
                Text(broadcasts.joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundStyle(.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.surface)
    }

    private var title: String {
        guard let comp = event.competitions.first,
              let home = comp.competitors.first(where: { $0.homeAway == "home" }),
              let away = comp.competitors.first(where: { $0.homeAway == "away" }) else {
            return event.name
        }
        let h = home.team.displayName ?? home.team.name ?? "Home"
        let a = away.team.displayName ?? away.team.name ?? "Away"
        return "\(h) vs. \(a)"
    }

    private var kickoffLabel: String {
        guard let date = espn.parseDate(event.date) else { return event.date }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

// MARK: - Circle Glass Back Button

struct CircleGlassBackButton: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                .background(.black.opacity(0.5))
                .clipShape(Circle())
        }
    }
}
