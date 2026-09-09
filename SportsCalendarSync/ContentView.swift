import SwiftUI
import SwiftData

private var launchArgOpenTeamDetail: String? {
    #if DEBUG
    guard let i = CommandLine.arguments.firstIndex(of: "-open-team"),
          i + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[i + 1]
    #else
    return nil
    #endif
}

enum AppTab: Int, CaseIterable {
    case following
    case discover
    case profile
}

struct ContentView: View {
    @State private var selectedTab: AppTab = {
        #if DEBUG
        if let i = CommandLine.arguments.firstIndex(of: "-initial-tab"),
           i + 1 < CommandLine.arguments.count {
            switch CommandLine.arguments[i + 1] {
            case "discover": return .discover
            case "profile": return .profile
            default: return .following
            }
        }
        #endif
        return .following
    }()
    @State private var leagueFilter: League?
    @State private var followingPath: [TrackedTeam] = []
    @State private var didOpenRequestedTeam = false
    @Query private var allTeams: [TrackedTeam]

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $followingPath) {
                FollowingView(leagueFilter: $leagueFilter)
                    .navigationDestination(for: TrackedTeam.self) { team in
                        TeamDetailView(team: team)
                    }
            }
            .tabItem { Label("Following", systemImage: "calendar.badge.checkmark") }
            .tag(AppTab.following)

            NavigationStack {
                DiscoverView(leagueFilter: $leagueFilter)
            }
            .tabItem { Label("Discover", systemImage: "magnifyingglass") }
            .tag(AppTab.discover)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.profile)
        }
        .task(id: allTeams.count) {
            #if DEBUG
            if let match = launchArgOpenTeamDetail,
               !didOpenRequestedTeam,
               let team = allTeams.first(where: {
                   $0.name.localizedCaseInsensitiveContains(match)
               }) {
                didOpenRequestedTeam = true
                selectedTab = .following
                followingPath = [team]
            }
            #endif
        }
    }
}

struct CompetitionFilterMenu: View {
    @Binding var selection: League?

    var body: some View {
        Menu {
            Picker("Competition", selection: $selection) {
                Text("All competitions").tag(nil as League?)
                ForEach(League.allCases) { league in
                    Text(league.displayName).tag(league as League?)
                }
            }
        } label: {
            Text(selection?.shortName ?? "All competitions")
        }
        .accessibilityLabel("Competition filter")
        .accessibilityValue(selection?.displayName ?? "All competitions")
    }
}
