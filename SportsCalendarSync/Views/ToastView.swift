import SwiftUI

enum ToastStyle { case success, danger, info }

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: ToastStyle
}

@MainActor
final class ToastManager: ObservableObject {
    @Published var current: Toast?

    func show(_ message: String, style: ToastStyle = .info) {
        current = Toast(message: message, style: style)
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if current?.message == message { current = nil }
        }
    }
}

struct ToastView: View {
    let toast: Toast
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
        .foregroundStyle(tint)
    }

    private var iconName: String {
        switch toast.style {
        case .success: return "checkmark.circle.fill"
        case .danger:  return "xmark.octagon.fill"
        case .info:    return "info.circle.fill"
        }
    }

    private var tint: Color {
        switch toast.style {
        case .success: return .green
        case .danger:  return .red
        case .info:    return .primary
        }
    }
}

private struct ToastModifier: ViewModifier {
    @ObservedObject var manager: ToastManager
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let t = manager.current {
                ToastView(toast: t)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: manager.current)
    }
}

extension View {
    func toast(_ manager: ToastManager) -> some View { modifier(ToastModifier(manager: manager)) }
}
