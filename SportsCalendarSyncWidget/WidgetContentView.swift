import SwiftUI
import WidgetKit
import UIKit

/// Shared by the actual WidgetKit extension and the opt-in native design review screen.
struct WidgetContentView: View {
    let fixtures: [WidgetFixture]
    let family: WidgetFamily
    var isReview = false
    var hasFollowedTeams = true
    var needsOpen = false

    private var visible: [WidgetFixture] {
        Array(fixtures.prefix(family == .systemLarge ? 4 : family == .systemMedium ? 2 : 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemMedium ? 2 : 6) {
            HStack(spacing: 5) {
                Image(systemName: isReview ? "testtube.2" : "soccerball")
                    .foregroundStyle(.blue)
                Text(isReview ? "Mock data" : family == .systemSmall ? "Next match" : "Upcoming matches")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .font(.system(size: family == .systemMedium ? 10 : 11, weight: .semibold))

            if visible.isEmpty {
                emptyState
            } else if family == .systemSmall, let fixture = visible.first {
                matchup(fixture)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, fixture in
                        fixtureRow(fixture)
                            .frame(maxHeight: .infinity)
                        if index < visible.count - 1 {
                            Divider().opacity(0.45)
                                .padding(.vertical, family == .systemLarge ? 2 : 0)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.primary)
    }

    private func matchup(_ fixture: WidgetFixture) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                WidgetTeamCrest(reference: fixture.homeLogoURL, name: fixture.homeTeam, size: 43.2, review: isReview)
                    .frame(maxWidth: .infinity)
                WidgetTeamCrest(reference: fixture.awayLogoURL, name: fixture.awayTeam, size: 43.2, review: isReview)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(fixture.kickoff, format: .dateTime.hour().minute())
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text(fixture.kickoff, format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            }
            .lineLimit(1).minimumScaleFactor(0.9)
            Text(fixture.competition)
                .font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(fixture))
    }

    private func fixtureRow(_ fixture: WidgetFixture) -> some View {
        GeometryReader { geometry in
            let availableWidth = max(0, geometry.size.width - 16)
            HStack(spacing: 8) {
                teamColumn(fixture.homeTeam, logo: fixture.homeLogoURL)
                    .frame(width: availableWidth * 0.3)
                VStack(spacing: 0.5) {
                    Text(kickoffLabel(fixture.kickoff))
                        .font(.system(size: family == .systemLarge ? 16 : 14, weight: .bold))
                        .monospacedDigit().foregroundStyle(.primary)
                        .minimumScaleFactor(0.85)
                    Text(fixture.kickoff, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    if let venue = fixture.venueLabel { Text(venue) }
                    Text(fixture.competition)
                    if family != .systemMedium, let broadcast = fixture.broadcastLabel { Text(broadcast) }
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary).lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(width: availableWidth * 0.4)
                .fixedSize(horizontal: false, vertical: true)

                teamColumn(fixture.awayTeam, logo: fixture.awayLogoURL)
                    .frame(width: availableWidth * 0.3)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(fixture))
    }

    private func teamColumn(_ name: String, logo: String?) -> some View {
        WidgetTeamCrest(reference: logo, name: name, size: 37.8, review: isReview)
    }

    private func kickoffLabel(_ date: Date) -> AttributedString {
        var label = date.formatted(.dateTime.hour().minute().attributed)
        for run in label.runs where run.dateField == .amPM {
            label[run.range].font = .system(size: 9, weight: .medium)
        }
        return label
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: needsOpen ? "arrow.up.forward.app" : "calendar")
                .font(.title2).foregroundStyle(.blue)
            Text(needsOpen ? "Your matches, here." : "Nothing scheduled yet.")
                .font(.headline)
            Text(needsOpen ? "Open Sports Sync to load your fixtures." : hasFollowedTeams
                 ? "Upcoming fixtures will appear after your next sync." : "Follow a team in Sports Sync to get started.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private func accessibilityLabel(_ fixture: WidgetFixture) -> String {
        ["\(fixture.homeTeam) versus \(fixture.awayTeam), \(fixture.competition), \(fixture.kickoff.formatted(date: .complete, time: .shortened))", fixture.venueLabel, fixture.broadcastLabel.map { "Watch on \($0)" }].compactMap { $0 }.joined(separator: ", ")
    }
}

private struct WidgetTeamCrest: View {
    let reference: String?
    let name: String
    let size: CGFloat
    let review: Bool

    var body: some View {
        Group {
            if let reference, let url = WidgetSnapshot.crestURL(for: reference, review: review),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Text(String(name.split(separator: " ").prefix(2).compactMap(\.first)))
                    .font(.system(size: max(8, size * 0.3), weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
