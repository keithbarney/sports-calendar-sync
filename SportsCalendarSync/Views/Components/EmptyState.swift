import SwiftUI

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            LucideIcon(name: icon, size: 48)
                .foregroundStyle(.textTertiary)

            Text(title)
                .font(.title3)
                .foregroundStyle(.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
