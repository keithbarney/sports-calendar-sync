import SwiftUI

struct SectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.textTertiary)
            .tracking(1)
            .textCase(.uppercase)
    }
}

extension View {
    func sectionHeader() -> some View {
        modifier(SectionHeaderModifier())
    }
}
