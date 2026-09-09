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
    @State private var showingUnfollowConfirmation = false
    @State private var showingCompetitionSheet = false

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

    private var isFollowed: Bool { !followedCompetitionTeams.isEmpty }

    private var league: League? { League(rawValue: leagueSlug) }

    private var sourceCompetition: Competition? { Competition(rawValue: leagueSlug) }

    private var recommendedCompetitions: [Competition] {
        Competition.recommendedCompetitions(forTeamNamed: displayName)
    }

    private var availableCompetitions: [Competition] {
        var competitions = recommendedCompetitions
        if let sourceCompetition, !competitions.contains(sourceCompetition) {
            competitions.insert(sourceCompetition, at: 0)
        }
        return competitions
    }

    private var followedCompetitions: [Competition] {
        availableCompetitions.filter(isFollowing)
    }

    private var displayName: String { tracked?.name ?? initialName }
    private var logoURL: String? { tracked?.logoURL ?? initialLogoURL }
    private var primaryColor: String? { tracked?.primaryColor ?? initialPrimaryColor }
    private var abbreviation: String? { tracked?.abbreviation ?? initialAbbreviation }

    /// Upcoming fixture count & list — uses stored TrackedGame if followed, else ESPN preview.
    private var fixtureCount: Int { isFollowed ? storedFixtures.count : previewFixtures.count }
    private var recentCount: Int { isFollowed ? storedRecent.count : previewRecent.count }

    private var followedCompetitionTeams: [TrackedTeam] {
        let matchingCompetitions = Set(recommendedCompetitions.map(\.slug))
        let matchingTeams = followedTeams.filter { team in
            guard matchingCompetitions.contains(team.leagueSlug) else { return false }
            return isSameClubName(team.name, displayName)
        }
        return matchingTeams.isEmpty ? (tracked.map { [$0] } ?? []) : matchingTeams
    }

    private var followedTeamIDs: Set<String> {
        Set(followedCompetitionTeams.map(\.espnId))
    }

    private var followedCompetitionSlugs: Set<String> {
        Set(followedCompetitionTeams.map(\.leagueSlug))
    }

    private var storedFixtures: [TrackedGame] {
        let now = Date().addingTimeInterval(-3 * 60 * 60)
        return allGames
            .filter { followedTeamIDs.contains($0.followedTeamId) && followedCompetitionSlugs.contains($0.leagueSlug) }
            .filter { $0.kickoff >= now }
            .sorted { $0.kickoff < $1.kickoff }
    }

    private var storedRecent: [TrackedGame] {
        let now = Date()
        return allGames
            .filter { followedTeamIDs.contains($0.followedTeamId) && followedCompetitionSlugs.contains($0.leagueSlug) }
            .filter { $0.kickoff < now }
            .sorted { $0.kickoff > $1.kickoff }
            .prefix(5)
            .map { $0 }
    }

    private func isSameClubName(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLHS = normalizeClubName(lhs)
        let normalizedRHS = normalizeClubName(rhs)
        if normalizedLHS == normalizedRHS { return true }

        let aliases: Set<Set<String>> = [
            ["lafc", "losangelesfc"],
            ["manchesterunited", "manutd"]
        ]
        return aliases.contains { $0.contains(normalizedLHS) && $0.contains(normalizedRHS) }
    }

    private func normalizeClubName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    CrestView(url: logoURL, size: 100, fallbackIcon: "sportscourt")
                        .accessibilityHidden(true)
                    Text(displayName)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    if let abbreviation {
                        Text(abbreviation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .listRowBackground(Color.clear)

            Section {
                if isFollowed && availableCompetitions.count > 1 {
                    competitionControls
                } else if let league {
                    LabeledContent("Competition", value: league.displayName)
                }
                LabeledContent("Upcoming fixtures", value: "\(fixtureCount)")
                LabeledContent("Recent fixtures", value: "\(recentCount)")
            }

            fixturesSection

            if recentCount > 0 {
                recentSection
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isAdding {
                    ProgressView().accessibilityLabel("Saving competitions")
                } else if isFollowed {
                    Menu {
                        Button(role: .destructive) {
                            showingUnfollowConfirmation = true
                        } label: {
                            Label("Unfollow team", systemImage: "minus.circle")
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Following")
                        }
                    }
                } else {
                    Button("Follow") { showingCompetitionSheet = true }
                }
            }
        }
        .confirmationDialog("Unfollow \(displayName)?", isPresented: $showingUnfollowConfirmation, titleVisibility: .visible) {
            Button("Unfollow team", role: .destructive) { unfollow() }
        } message: {
            Text("This will unfollow the team and remove all of its fixtures from your calendar.")
        }
        .sheet(isPresented: $showingCompetitionSheet) {
            CompetitionSelectionSheet(
                teamName: displayName,
                competitions: availableCompetitions,
                initialSelection: Set(followedCompetitions),
                isInitialFollow: !isFollowed
            ) { selection in
                Task { await saveCompetitionSelection(selection) }
            }
        }
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            // Followed teams display the locally synced fixtures. The app-level
            // refresh owns automatic syncing; opening a team must not trigger it.
            if !isFollowed {
                await refresh()
            }
        }
        .refreshable { await refresh() }
    }

    // MARK: - Fixtures

    private var fixturesSection: some View {
        Section("Upcoming fixtures") {
            if fixtureCount == 0 {
                if isRefreshing {
                    ProgressView("Loading fixtures…")
                } else {
                    ContentUnavailableView("No upcoming fixtures", systemImage: "calendar", description: Text("New fixtures will appear here when they are available."))
                }
            } else if isFollowed {
                ForEach(storedFixtures) { game in
                    FixtureRow(game: game)
                }
            } else {
                ForEach(previewFixtures, id: \.id) { event in
                    PreviewFixtureRow(event: event, espn: espn, competitionName: league?.displayName)
                }
            }
        }
    }

    private var recentSection: some View {
        Section("Recent fixtures") {
            if isFollowed {
                ForEach(storedRecent) { game in
                    FixtureRow(game: game)
                }
            } else {
                ForEach(previewRecent, id: \.id) { event in
                    PreviewFixtureRow(event: event, espn: espn, competitionName: league?.displayName)
                }
            }
        }
    }

    private var competitionControls: some View {
        Button {
            showingCompetitionSheet = true
        } label: {
            LabeledContent("Manage competitions", value: "\(followedCompetitions.count) of \(availableCompetitions.count)")
        }
    }

    // MARK: - Data

    private func isFollowing(_ competition: Competition) -> Bool {
        followedTeams.contains { team in
            guard team.leagueSlug == competition.slug else { return false }
            return isSameClubName(team.name, displayName)
        }
    }

    private func trackedTeam(for competition: Competition) -> TrackedTeam? {
        followedTeams.first {
            $0.leagueSlug == competition.slug && isSameClubName($0.name, displayName)
        }
    }

    private func makeESPNTeam() -> ESPNTeam {
        ESPNTeam(
            id: espnId,
            name: initialName,
            displayName: initialName,
            shortDisplayName: nil,
            abbreviation: initialAbbreviation,
            color: initialPrimaryColor,
            logos: initialLogoURL.map { [ESPNLogo(href: $0)] }
        )
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        if isFollowed {
            for team in followedCompetitionTeams {
                guard let competition = Competition(rawValue: team.leagueSlug) else { continue }
                _ = await teamManager.syncSchedule(
                    for: team,
                    context: context,
                    espn: espn,
                    calendar: calendar,
                    league: competition,
                    notifications: notifications
                )
            }
        } else if let league {
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

    private func saveCompetitionSelection(_ selection: Set<Competition>) async {
        guard let sourceCompetition else { return }
        isAdding = true
        defer { isAdding = false }

        let selected = availableCompetitions.filter(selection.contains)
        let added = await teamManager.followAcrossCompetitions(
            espnTeam: makeESPNTeam(),
            sourceCompetition: sourceCompetition,
            competitions: selected,
            context: context,
            espn: espn,
            calendar: calendar,
            notifications: notifications
        )

        for competition in availableCompetitions where !selection.contains(competition) {
            if let team = trackedTeam(for: competition) {
                teamManager.stopFollowingCompetition(
                    team: team,
                    context: context,
                    notifications: notifications
                )
            }
        }

        let message = added > 0
            ? "Following \(selection.count) competition\(selection.count == 1 ? "" : "s")"
            : "Competition preferences saved"
        toast.show(message, icon: "checkmark.circle.fill", isDestructive: false)
    }

    private func unfollow() {
        let teams = followedCompetitionTeams
        guard !teams.isEmpty else { return }
        for team in teams {
            teamManager.unfollow(team: team, context: context, calendar: calendar, notifications: notifications)
        }
        toast.show("Unfollowed \(displayName)", icon: "minus.circle.fill", isDestructive: true)
        dismiss()
    }
}

// MARK: - Competition Selection

private struct CompetitionSelectionSheet: View {
    let teamName: String
    let competitions: [Competition]
    let isInitialFollow: Bool
    let onSave: (Set<Competition>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<Competition>

    init(
        teamName: String,
        competitions: [Competition],
        initialSelection: Set<Competition>,
        isInitialFollow: Bool,
        onSave: @escaping (Set<Competition>) -> Void
    ) {
        self.teamName = teamName
        self.competitions = competitions
        self.isInitialFollow = isInitialFollow
        self.onSave = onSave
        _selected = State(initialValue: initialSelection.isEmpty ? Set(competitions) : initialSelection)
    }

    private var allSelected: Bool {
        !competitions.isEmpty && selected.count == competitions.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(isInitialFollow ? "Choose which competitions to follow." : "Choose which competitions sync to your calendar.")
                        .foregroundStyle(.secondary)
                }

                Section("Competitions") {
                    ForEach(competitions) { competition in
                        Toggle(competition.displayName, isOn: Binding(
                            get: { selected.contains(competition) },
                            set: { isSelected in
                                if isSelected {
                                    selected.insert(competition)
                                } else {
                                    selected.remove(competition)
                                }
                            }
                        ))
                    }
                }

                Section {
                    Button(allSelected ? "Clear all" : "Select all") {
                        selected = allSelected ? [] : Set(competitions)
                    }
                } footer: {
                    Text("Existing calendar events are kept if you stop following a competition.")
                }
            }
            .navigationTitle(isInitialFollow ? "Follow \(teamName)" : "Manage Competitions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isInitialFollow ? "Follow" : "Save") {
                        onSave(selected)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

}

// MARK: - Fixture Row

struct FixtureRow: View {
    let game: TrackedGame

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(game.title)
                .font(.headline)
                .foregroundStyle(.primary)
            if let competitionName {
                Text(competitionName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text(kickoffLabel)
                if let venue = game.venue {
                    Text("·").foregroundStyle(.tertiary)
                    Text(venue)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !game.broadcasts.isEmpty {
                Text(game.broadcasts.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var kickoffLabel: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: game.kickoff)
    }

    private var competitionName: String? {
        Competition(rawValue: game.leagueSlug)?.displayName
    }
}

// MARK: - Preview Fixture Row (unfollowed teams — not yet persisted)

private struct PreviewFixtureRow: View {
    let event: ESPNEvent
    let espn: ESPNService
    let competitionName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            if let competitionName {
                Text(competitionName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text(kickoffLabel)
                if let venue = event.competitions.first?.venue?.fullName {
                    Text("·").foregroundStyle(.tertiary)
                    Text(venue)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let broadcasts = event.competitions.first?.broadcasts?.flatMap({ $0.names ?? [] }), !broadcasts.isEmpty {
                Text(broadcasts.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
