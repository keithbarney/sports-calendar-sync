#if DEBUG
import SwiftUI
import SwiftData
import WidgetKit

/// Native renderer review, explicitly separate from proof of a live Home Screen widget.
struct WidgetDesignReviewView: View {
    @Query private var teams: [TrackedTeam]
    @Query private var games: [TrackedGame]
    @State private var dark = false
    @State private var artworkRevision = 0

    private var fixtures: [WidgetFixture] {
        WidgetSnapshot.make(teams: teams, games: games).fixtures
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Widget renderer preview")
                        .font(.subheadline).foregroundStyle(.secondary)
                    preview("Small", family: .systemSmall, width: 170, height: 170)
                    preview("Medium", family: .systemMedium, width: 364, height: 170)
                    preview("Large", family: .systemLarge, width: 364, height: 382)
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Widgets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle("Dark appearance", isOn: $dark).toggleStyle(.switch)
                }
            }
        }
        .preferredColorScheme(dark ? .dark : .light)
        .environment(\.colorScheme, dark ? .dark : .light)
        .onReceive(NotificationCenter.default.publisher(for: WidgetSnapshot.artworkDidChange)) { _ in
            artworkRevision += 1
        }
    }

    private func preview(_ title: String, family: WidgetFamily, width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            WidgetContentView(fixtures: fixtures, family: family, isReview: true, hasFollowedTeams: !teams.isEmpty)
                .id(artworkRevision)
                .padding(16)
                .frame(width: width, height: height)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        }
    }
}
#endif
