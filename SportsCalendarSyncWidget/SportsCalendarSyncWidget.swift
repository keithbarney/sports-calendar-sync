import WidgetKit
import SwiftUI

struct GameSyncEntry: TimelineEntry {
    let date: Date
    let fixtures: [WidgetFixture]
    let hasFollowedTeams: Bool
    var isReview = false
    var needsOpen = false

    static var placeholder: GameSyncEntry {
        GameSyncEntry(date: Date(), fixtures: (0..<6).map { index in
            WidgetFixture(id: "preview-\(index)", homeTeam: ["Arsenal", "SV Darmstadt 98", "Real Madrid"][index % 3],
                          awayTeam: ["Liverpool", "Hannover 96", "Barcelona"][index % 3],
                          competition: ["EPL", "2. Bundesliga", "La Liga"][index % 3],
                          kickoff: Date().addingTimeInterval(Double(index + 1) * 86400))
        }, hasFollowedTeams: true)
    }
}

struct GameSyncProvider: TimelineProvider {
    func placeholder(in context: Context) -> GameSyncEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (GameSyncEntry) -> Void) {
        let entry = entries().first!
        completion(context.isPreview && entry.fixtures.isEmpty ? .placeholder : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GameSyncEntry>) -> Void) {
        completion(Timeline(entries: entries(), policy: .after(Date().addingTimeInterval(3600))))
    }

    private func entries() -> [GameSyncEntry] {
        let now = Date()
        var isReview = false
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.groupID) else {
            return [GameSyncEntry(date: now, fixtures: [], hasFollowedTeams: false, needsOpen: true)]
        }
        var url = directory.appendingPathComponent(WidgetSnapshot.filename)
        #if DEBUG && targetEnvironment(simulator)
        let reviewURL = directory.appendingPathComponent(WidgetSnapshot.reviewFilename)
        if FileManager.default.fileExists(atPath: reviewURL.path) {
            url = reviewURL
            isReview = true
        }
        #endif
        guard let data = try? Data(contentsOf: url), let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return [GameSyncEntry(date: now, fixtures: [], hasFollowedTeams: false, needsOpen: true)]
        }
        // Queue the next state at kickoff, so a started match drops out even without a new app sync.
        let dates = [now] + Array(Set(snapshot.upcoming(at: now).map(\.kickoff))).sorted()
        return dates.map { date in
            GameSyncEntry(date: date, fixtures: Array(snapshot.upcoming(at: date).prefix(6)),
                          hasFollowedTeams: snapshot.hasFollowedTeams, isReview: isReview)
        }
    }
}

struct SportsCalendarSyncWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GameSyncEntry

    #if DEBUG
    private let appURL = URL(string: "sportssync-local://following")
    #else
    private let appURL = URL(string: "sportssync://following")
    #endif

    var body: some View {
        WidgetContentView(fixtures: entry.fixtures, family: family, isReview: entry.isReview,
                          hasFollowedTeams: entry.hasFollowedTeams, needsOpen: entry.needsOpen)
            .padding(16)
            .widgetURL(appURL)
    }
}

@main
struct SportsCalendarSyncWidgetBundle: Widget {
    let kind = WidgetSnapshot.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GameSyncProvider()) { entry in
            SportsCalendarSyncWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Upcoming Matches")
        .description("Upcoming matches across all your followed teams and competitions.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
