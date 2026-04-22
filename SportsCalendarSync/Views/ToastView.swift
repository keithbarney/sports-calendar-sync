import SwiftUI

struct ToastMessage: Equatable {
    let text: String
    let icon: String
    let isDestructive: Bool

    init(_ text: String, icon: String = "checkmark.circle.fill", isDestructive: Bool = false) {
        self.text = text
        self.icon = icon
        self.isDestructive = isDestructive
    }
}

struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: message.icon)
                .font(.title3)
                .foregroundStyle(message.isDestructive ? Color.danger : Color.success)

            Text(message.text)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.textPrimary)
                .lineLimit(2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .background(Color.surfaceElevated.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// Observable toast manager — API parity with ShowSync.
@MainActor
class ToastManager: ObservableObject {
    @Published var current: ToastMessage?

    func show(_ text: String, icon: String = "checkmark.circle.fill", isDestructive: Bool = false) {
        withAnimation(.spring(duration: 0.3)) {
            current = ToastMessage(text, icon: icon, isDestructive: isDestructive)
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.2)) {
                if current?.text == text {
                    current = nil
                }
            }
        }
    }
}

// Modifier to attach toast to any view
struct ToastModifier: ViewModifier {
    @ObservedObject var manager: ToastManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = manager.current {
                ToastView(message: message)
                    .padding(.bottom, 100)
            }
        }
    }
}

extension View {
    func toast(_ manager: ToastManager) -> some View {
        modifier(ToastModifier(manager: manager))
    }
}
