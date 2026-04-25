import SwiftUI

struct DetailChip: View {
    let label: String
    var icon: String? = nil
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            if let icon { LucideIcon(name: icon, size: 10) }
            Text(label).font(.system(size: 12)).lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.surfaceElevated)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct ChipData: Identifiable {
    var id: String { label }
    let label: String
    var icon: String? = nil
    let color: Color
}
