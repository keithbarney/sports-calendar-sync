import SwiftUI
import SwiftData

struct DiscoverView: View {
    @EnvironmentObject private var espn: ESPNService
    @EnvironmentObject private var teamManager: TeamManager
    @EnvironmentObject private var calendar: CalendarService
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var toast: ToastManager
    @Environment(\.modelContext) private var context
    @Query private var followed: [TrackedTeam]
    @StateObject private var catalog = DiscoveryCatalog()
    @State private var query = ""
    @State private var addingIDs: Set<String> = []
    @State private var followSelection: DiscoverFollowSelection?
    @State private var showingPopularityInfo = false
    @ScaledMetric(relativeTo: .body) private var cardWidth = 136
    @ScaledMetric(relativeTo: .title2) private var crestSize = 56
    @ScaledMetric(relativeTo: .title) private var cardActionSize = 32
    @ScaledMetric(relativeTo: .title3) private var rowActionSize = 22
    @ScaledMetric(relativeTo: .body) private var competitionLogoSize = 40

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var searchResults: [DiscoveryTeam] { DiscoveryTeam.search(query, in: catalog.teams) }

    var body: some View {
        List {
            if isSearching {
                Section("Teams") {
                    ForEach(searchResults) { entry in teamRow(entry) }
                    if searchResults.isEmpty && !catalog.isLoading {
                        ContentUnavailableView.search(text: query)
                    }
                }
            } else {
                Section {
                    if catalog.popular.isEmpty {
                        if catalog.isLoading {
                            ProgressView("Loading popular teams…")
                        } else {
                            ContentUnavailableView("Teams unavailable", systemImage: "sportscourt",
                                                   description: Text("Try loading teams again."))
                        }
                    } else {
                        popularCarousel
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    HStack {
                        Text("Popular teams")
                        Spacer()
                        Button { showingPopularityInfo = true } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("About popular teams")
                    }
                }

                Section("Browse competitions") {
                    ForEach(DiscoveryTeam.domesticLeagues.prefix(6)) { competition in
                        competitionLink(competition)
                    }
                    NavigationLink("All competitions") {
                        List {
                            Section("Leagues") {
                                ForEach(DiscoveryTeam.domesticLeagues) { competition in competitionLink(competition) }
                            }
                            Section("Cups and other competitions") {
                                ForEach(Competition.allCases.filter { !DiscoveryTeam.domesticLeagues.contains($0) }) { competition in
                                    competitionLink(competition)
                                }
                            }
                        }
                        .modifier(ReadableListLayout())
                        .navigationTitle("Competitions")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }

            if catalog.isLoading {
                Section {
                    ProgressView(isSearching ? "Searching more competitions…" : "Loading teams…")
                }
            }
            if !catalog.failed.isEmpty {
                Section {
                    Label("Some teams could not be loaded", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Button("Retry") { Task { await catalog.loadAll(using: espn) } }
                        .disabled(catalog.isLoading)
                } footer: {
                    Text("Results from available competitions are shown.")
                }
            }
        }
        .modifier(ReadableListLayout())
        .navigationTitle("Discover")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search teams")
        .task { await catalog.loadAll(using: espn) }
        .sheet(item: $followSelection) { selection in
            CompetitionSelectionSheet(
                teamName: selection.entry.name,
                competitions: selection.competitions,
                initialSelection: [],
                isInitialFollow: true,
                unavailableCompetitions: selection.unavailable
            ) { selected in
                Task { await saveFollow(selection.entry, competitions: selected) }
            }
        }
        .sheet(isPresented: $showingPopularityInfo) {
            NavigationStack {
                Form {
                    Section {
                        Text("Ten clubs with the largest combined social-media followings in the CIES Football Observatory’s May 2026 ranking.")
                        Text("This selection uses followers across Facebook, Instagram, TikTok, X and YouTube. It is not based on Sports Sync activity.")
                            .foregroundStyle(.secondary)
                        Link("View CIES ranking", destination: PopularTeams.sourceURL)
                    }
                }
                .navigationTitle("Popular teams")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingPopularityInfo = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var popularCarousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(catalog.popular) { entry in
                    GroupBox {
                        VStack(spacing: 12) {
                            NavigationLink {
                                TeamDetailView(espnTeam: entry.team, league: entry.competition)
                            } label: {
                                VStack(spacing: 10) {
                                    CrestView(url: entry.team.crestURL, size: crestSize)
                                        .accessibilityHidden(true)
                                    Text(entry.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(2, reservesSpace: true)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("popular-team-\(ESPNTeam.clubNameKey(entry.name))")
                            followButton(entry, prominent: true)
                        }
                    }
                    .backgroundStyle(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(width: cardWidth)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 4)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("popular-teams-carousel")
    }

    private func teamRow(_ entry: DiscoveryTeam) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                TeamDetailView(espnTeam: entry.team, league: entry.competition)
            } label: {
                FeedRow(logoURL: entry.team.crestURL, fallbackIcon: "sportscourt", title: entry.name) {
                    Text("\(entry.competition.shortName) · \(entry.competition.country)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if isFollowing(entry) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: rowActionSize))
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Following")
            } else {
                followButton(entry)
                    .fixedSize()
            }
        }
    }

    @ViewBuilder
    private func followButton(_ entry: DiscoveryTeam, prominent: Bool = false) -> some View {
        if addingIDs.contains(entry.id) {
            ProgressView()
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Loading \(entry.name)")
        } else if isFollowing(entry) {
            NavigationLink {
                TeamDetailView(espnTeam: entry.team, league: entry.competition)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: prominent ? cardActionSize : rowActionSize))
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Manage \(entry.name)")
            .accessibilityValue("Following")
        } else {
            Button { Task { await prepareFollow(entry) } } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: prominent ? cardActionSize : rowActionSize))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Follow \(entry.name)")
            .disabled(!addingIDs.isEmpty)
        }
    }

    private func competitionLink(_ competition: Competition) -> some View {
        NavigationLink {
            CompetitionTeamsView(competition: competition, catalog: catalog) { entry in teamRow(entry) }
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let assetName = competition.logoAssetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: competition == .clubFriendlies ? "soccerball" : "trophy")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: competitionLogoSize, height: competitionLogoSize)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(competition.displayName)
                    Text(competition.country).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func isFollowing(_ entry: DiscoveryTeam) -> Bool {
        followed.contains { $0.espnId == entry.id || ESPNTeam.clubNameKey($0.name) == ESPNTeam.clubNameKey(entry.name) }
    }

    private func prepareFollow(_ entry: DiscoveryTeam) async {
        guard !addingIDs.contains(entry.id) else { return }
        addingIDs.insert(entry.id)
        defer { addingIDs.remove(entry.id) }
        do {
            let result = try await espn.getCompetitions(for: entry.team, source: entry.competition)
            followSelection = DiscoverFollowSelection(entry: entry, competitions: result.competitions, unavailable: result.unavailable)
        } catch {
            toast.show("Could not load competitions. Please try again.", icon: "exclamationmark.triangle", isDestructive: true)
        }
    }

    private func saveFollow(_ entry: DiscoveryTeam, competitions: Set<Competition>) async {
        addingIDs.insert(entry.id)
        defer { addingIDs.remove(entry.id) }
        let result = await teamManager.followAcrossCompetitions(
            espnTeam: entry.team, sourceCompetition: entry.competition,
            competitions: Competition.allCases.filter(competitions.contains), context: context,
            espn: espn, calendar: calendar, notifications: notifications
        )
        if result.failed.isEmpty {
            toast.show("Following \(entry.name)", icon: "checkmark.circle.fill", isDestructive: false)
        } else {
            toast.show("Could not follow: \(result.failed.map(\.displayName).joined(separator: ", ")). Please try again.",
                       icon: "exclamationmark.triangle", isDestructive: true)
        }
    }
}

private struct DiscoverFollowSelection: Identifiable {
    let entry: DiscoveryTeam
    let competitions: [Competition]
    let unavailable: [Competition]
    var id: String { entry.id }
}

private struct CompetitionTeamsView<Row: View>: View {
    let competition: Competition
    @ObservedObject var catalog: DiscoveryCatalog
    @ViewBuilder let row: (DiscoveryTeam) -> Row
    @EnvironmentObject private var espn: ESPNService
    @State private var query = ""

    private var entries: [DiscoveryTeam] {
        let teams = (catalog.teamsByCompetition[competition] ?? []).map { DiscoveryTeam(team: $0, competition: competition) }
        return query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? teams : DiscoveryTeam.search(query, in: teams)
    }

    var body: some View {
        List {
            ForEach(entries) { entry in row(entry) }
        }
        .modifier(ReadableListLayout())
        .overlay {
            if catalog.loading.contains(competition) {
                ProgressView("Loading teams…")
            } else if catalog.failed.contains(competition) {
                ContentUnavailableView {
                    Label("Teams unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Retry") { Task { await catalog.load(competition, using: espn) } }
                }
            } else if entries.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView("No teams available", systemImage: "sportscourt")
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .navigationTitle(competition.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search teams")
        .task { await catalog.load(competition, using: espn) }
    }
}
