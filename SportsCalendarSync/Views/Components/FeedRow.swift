import SwiftUI

/// Generic shared feed row — ported from ShowSync. Crest + title + ViewBuilder subtitle/trailing slots.
struct FeedRow<Subtitle: View, Trailing: View>: View {
    let logoURL: String?
    let fallbackIcon: String
    let title: String
    @ViewBuilder let subtitle: () -> Subtitle
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            CrestView(url: logoURL, size: 44, fallbackIcon: fallbackIcon)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                subtitle()
            }

            Spacer()

            trailing()
        }
    }
}

extension FeedRow where Trailing == EmptyView {
    init(logoURL: String?, fallbackIcon: String, title: String, @ViewBuilder subtitle: @escaping () -> Subtitle) {
        self.logoURL = logoURL
        self.fallbackIcon = fallbackIcon
        self.title = title
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
    }
}
