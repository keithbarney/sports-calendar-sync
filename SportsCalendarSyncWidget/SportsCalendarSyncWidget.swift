import WidgetKit
import SwiftUI
import SwiftData

struct GameSyncEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let kickoffDisplay: String?
    let isEmpty: Bool

    static let placeholder = GameSyncEntry(
        date: Date(),
        title: "Arsenal vs. Liverpool",
        subtitle: "Premier League",
        kickoffDisplay: "Sat 12:30",
        isEmpty: false
    )

    static let empty = GameSyncEntry(
        date: Date(),
        title: "No Upcoming",
        subtitle: "Follow teams to track fixtures",
        kickoffDisplay: nil,
        isEmpty: true
    )
}

struct GameSyncProvider: TimelineProvider {
    func placeholder(in context: Context) -> GameSyncEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (GameSyncEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GameSyncEntry>) -> Void) {
        let entry: GameSyncEntry
        do {
            let container = try ModelContainer(for: TrackedGame.self, TrackedTeam.self)
            let modelContext = ModelContext(container)

            let descriptor = FetchDescriptor<TrackedGame>(
                sortBy: [SortDescriptor(\.kickoff)]
            )
            let games = (try? modelContext.fetch(descriptor)) ?? []
            let now = Date()

            if let next = games.first(where: { $0.kickoff >= now }) {
                let leagueName = League(rawValue: next.leagueSlug)?.displayName ?? next.leagueSlug.uppercased()
                entry = GameSyncEntry(
                    date: now,
                    title: "\(next.homeTeamName) vs. \(next.awayTeamName)",
                    subtitle: leagueName,
                    kickoffDisplay: Self.formatKickoff(next.kickoff),
                    isEmpty: false
                )
            } else {
                entry = .empty
            }
        } catch {
            entry = .empty
        }

        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private static func formatKickoff(_ date: Date) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.locale = .current
        if cal.isDateInToday(date) {
            fmt.dateFormat = "h:mm a"
            return "Today \(fmt.string(from: date))"
        }
        if cal.isDateInTomorrow(date) {
            fmt.dateFormat = "h:mm a"
            return "Tomorrow \(fmt.string(from: date))"
        }
        if let week = cal.date(byAdding: .day, value: 7, to: Date()), date < week {
            fmt.dateFormat = "EEE h:mm a"
            return fmt.string(from: date)
        }
        fmt.dateFormat = "M/d h:mm a"
        return fmt.string(from: date)
    }
}

struct SportsCalendarSyncWidgetView: View {
    var entry: GameSyncEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "soccerball")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                Text("Sports")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }

            Spacer()

            Text(entry.title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(entry.subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

            if let kickoff = entry.kickoffDisplay {
                Text(kickoff)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }
}

@main
struct SportsCalendarSyncWidgetBundle: Widget {
    let kind: String = "SportsCalendarSyncWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GameSyncProvider()) { entry in
            SportsCalendarSyncWidgetView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Next Match")
        .description("Your next upcoming fixture.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
