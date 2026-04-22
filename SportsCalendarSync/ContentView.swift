import SwiftUI

enum AppTab: String, CaseIterable {
    case following, discover, profile
    var icon: String {
        switch self {
        case .following: return "star.fill"
        case .discover:  return "magnifyingglass"
        case .profile:   return "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @State private var tab: AppTab = .following
    @State private var leagueFilter: League? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .following: FollowingView(leagueFilter: $leagueFilter)
                case .discover:  DiscoverView(leagueFilter: $leagueFilter)
                case .profile:   ProfileView()
                }
            }

            FloatingTabBar(tab: $tab)
                .padding(.bottom, 12)
        }
    }
}

struct FloatingTabBar: View {
    @Binding var tab: AppTab
    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    Image(systemName: t.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 52, height: 44)
                        .foregroundStyle(tab == t ? .primary : .secondary)
                        .background(tab == t ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.clear), in: Capsule())
                }
            }
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 10, y: 4)
    }
}

struct SegmentedFilter: View {
    @Binding var selected: League?
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(label: "All", active: selected == nil) { selected = nil }
                ForEach(League.allCases) { league in
                    chip(label: league.shortName, active: selected == league) { selected = league }
                }
            }
            .padding(4)
        }
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    @ViewBuilder
    private func chip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(active ? .primary : .secondary)
                .background(active ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.clear), in: Capsule())
        }
    }
}
