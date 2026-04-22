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

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                subtitle()
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
