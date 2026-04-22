import SwiftUI

struct StatBox: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(.textPrimary)
            Text(label).font(.system(size: 12)).foregroundStyle(.textSecondary).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
    }
}
