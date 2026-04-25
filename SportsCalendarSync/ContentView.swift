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

    var label: String {
        switch self {
        case .following: return "Following"
        case .discover:  return "Discover"
        case .profile:   return "Settings"
        }
    }

    /// Lucide icon name (matches Assets.xcassets/Icons). Same set as TV & Movie Calendar Sync.
    var icon: String {
        switch self {
        case .following: return "calendar-check"
        case .discover:  return "search"
        case .profile:   return "user-round"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var calendarService: CalendarService
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
    @State private var leagueFilter: League? = nil
    @State private var isSearching = false
    @State private var navPath: [TrackedTeam] = []
    @Query private var allTeams: [TrackedTeam]

    private var showsFilter: Bool {
        selectedTab != .profile
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                tabContent
                    .id(selectedTab)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaPadding(.top, showsFilter ? 52 : 0)
                    .safeAreaPadding(.bottom, 80)

                VStack {
                    if showsFilter {
                        SegmentedFilter(selection: $leagueFilter)
                    }
                    Spacer()
                    if !isSearching {
                        FloatingTabBar(selection: $selectedTab)
                            .transition(.opacity)
                    }
                }
                .modifier(GlassContainerWrapper())
            }
            .background(Color.background)
            .toolbar(selectedTab == .profile ? .visible : .hidden, for: .navigationBar)
            .navigationDestination(for: TrackedTeam.self) { team in
                TeamDetailView(team: team)
            }
            .task {
                if !calendarService.isAuthorized {
                    _ = await calendarService.requestAccess()
                }
            }
            .task(id: allTeams.count) {
                #if DEBUG
                if let match = launchArgOpenTeamDetail,
                   navPath.isEmpty,
                   let team = allTeams.first(where: {
                       $0.name.localizedCaseInsensitiveContains(match)
                   }) {
                    navPath = [team]
                }
                #endif
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .following:
            FollowingView(leagueFilter: $leagueFilter)
        case .discover:
            DiscoverView(leagueFilter: $leagueFilter, isSearching: $isSearching)
        case .profile:
            ProfileView()
        }
    }
}

// MARK: - Floating Tab Bar

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = tab
                    }
                } label: {
                    LucideIcon(name: tab.icon, size: 24)
                        .foregroundStyle(selection == tab ? Color.accent : Color.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
            }
        }
        .frame(width: 170, height: 56)
        .capsuleGlass(shadow: true, interactive: true)
        .padding(.bottom, 12)
    }
}

// MARK: - Segmented Filter (top tabs)

struct SegmentedFilter: View {
    @Binding var selection: League?

    private var chips: [(League?, String)] {
        [(nil, "All")] + League.allCases.map { ($0 as League?, $0.shortName) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    let (value, label) = chip
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = value
                        }
                    } label: {
                        Text(label)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .contentShape(Capsule())
                            .background(
                                Capsule()
                                    .fill(selection == value ? Color.glassHighlight : .clear)
                            )
                            .foregroundStyle(selection == value ? Color.accent : Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 3)
        }
        .padding(3)
        .capsuleGlass(interactive: true)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

// MARK: - Glass Effect Container Wrapper

private struct GlassContainerWrapper: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer {
                content
            }
        } else {
            content
        }
    }
}
