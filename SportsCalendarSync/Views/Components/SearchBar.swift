import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search teams…"
    var isFocused: FocusState<Bool>.Binding? = nil
    var onClear: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            LucideIcon(name: "search", size: 16)
                .foregroundStyle(.textTertiary)

            TextField(placeholder, text: $text)
                .font(.callout)
                .foregroundStyle(.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .onSubmit { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                .ifLet(isFocused) { view, binding in
                    view.focused(binding)
                }

            if !text.isEmpty {
                Button {
                    text = ""
                    onClear?()
                } label: {
                    LucideIcon(name: "circle-x", size: 16)
                        .foregroundStyle(.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .modifier(SearchBarGlass())
    }
}

// MARK: - Search Bar Glass

private struct SearchBarGlass: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(Color.surfaceElevated)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Conditional Modifier Helper

extension View {
    @ViewBuilder
    func ifLet<T, Modified: View>(_ value: T?, transform: (Self, T) -> Modified) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}
