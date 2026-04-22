import SwiftUI

/// 3-state CTA ported from ShowSync. Parameterized for any Add/Added/Remove flow —
/// in SportsSync it's used as Follow / Following / Unfollow.
struct ActionButton: View {
    let isTracked: Bool
    let isAdding: Bool
    let removeTitle: String
    /// Label when not yet tracked (e.g. "Follow Team", "Add to Calendar").
    var addLabel: String = "Add to Calendar"
    /// Label when tracked and idle (e.g. "Following", "Added to Calendar").
    var addedLabel: String = "Added to Calendar"
    /// Label when user taps the Added state to reveal the remove action (e.g. "Unfollow Team").
    var removeLabel: String = "Remove from Calendar"
    /// Confirmation message shown above the destructive button.
    var confirmationMessage: String = "This will remove it from your feed and delete all calendar events."
    let onAdd: () -> Void
    let onRemove: () -> Void

    @State private var showRemoveState = false
    @State private var showRemoveConfirmation = false

    var body: some View {
        Group {
            if isTracked && showRemoveState {
                Button { showRemoveConfirmation = true } label: {
                    buttonContent(icon: "x", text: removeLabel, style: .remove)
                }
            } else if isTracked {
                Button { showRemoveState = true } label: {
                    buttonContent(icon: "check", text: addedLabel, style: .added)
                }
            } else {
                Button { onAdd() } label: {
                    buttonContent(icon: isAdding ? nil : "plus", text: isAdding ? "" : addLabel, style: .add)
                }
                .disabled(isAdding)
            }
        }
        .confirmationDialog("Remove \(removeTitle)?", isPresented: $showRemoveConfirmation, titleVisibility: .visible) {
            Button(removeLabel, role: .destructive) { onRemove() }
        } message: {
            Text(confirmationMessage)
        }
    }

    private enum ButtonStyle {
        case add, added, remove

        var foreground: Color {
            switch self {
            case .add: .textPrimary
            case .added: .success
            case .remove: .danger
            }
        }

        var borderColor: Color {
            switch self {
            case .add: .border
            case .added: .success
            case .remove: .danger
            }
        }
    }

    private func buttonContent(icon: String?, text: String, style: ButtonStyle) -> some View {
        HStack(spacing: 12) {
            if let icon {
                LucideIcon(name: icon, size: 20)
            } else {
                ProgressView().tint(style.foreground)
            }
            if !text.isEmpty {
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .foregroundStyle(style.foreground)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(
            Capsule()
                .fill(Color.surface)
        )
        .overlay(
            Capsule()
                .stroke(style.borderColor, lineWidth: 2)
        )
    }
}
