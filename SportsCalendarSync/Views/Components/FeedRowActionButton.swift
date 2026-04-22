import SwiftUI

/// Shared add/remove icon button used in discover rows. Ported from ShowSync.
struct FeedRowActionButton: View {
    let isTracked: Bool
    let isAdding: Bool
    let onAdd: () -> Void
    var onRemove: (() -> Void)? = nil

    var body: some View {
        if isTracked {
            Button {
                onRemove?()
            } label: {
                LucideIcon(name: "circle-check", size: 24)
                    .foregroundStyle(.textPrimary)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .highPriorityGesture(TapGesture().onEnded { onRemove?() })
        } else {
            Button {
                onAdd()
            } label: {
                if isAdding {
                    ProgressView().tint(.textTertiary)
                } else {
                    LucideIcon(name: "circle-plus", size: 24)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .disabled(isAdding)
            .highPriorityGesture(TapGesture().onEnded { onAdd() })
        }
    }
}
