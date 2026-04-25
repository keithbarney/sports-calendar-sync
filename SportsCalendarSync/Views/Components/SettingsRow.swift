import SwiftUI

struct SettingsRow: View {
    let icon: String
    let label: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                LucideIcon(name: icon, size: 16)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 24)

                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                if isSelected {
                    LucideIcon(name: "check", size: 14)
                        .foregroundStyle(Color.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background(isSelected ? Color.surfaceElevated : .clear)
        }
        .buttonStyle(.plain)
    }
}
