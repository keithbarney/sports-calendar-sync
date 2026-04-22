import SwiftUI

struct CapsuleGlassModifier: ViewModifier {
    var shadow: Bool = false
    var interactive: Bool = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if interactive {
                content.glassEffect(.regular.interactive(), in: .capsule)
            } else {
                content.glassEffect(.regular, in: .capsule)
            }
        } else {
            if shadow {
                content.background(
                    Capsule()
                        .fill(Color.glassFill)
                        .overlay(Capsule().stroke(Color.glassBorder, lineWidth: 1))
                        .shadow(color: Color.glassShadow, radius: 20, y: 8)
                )
            } else {
                content.background(
                    Capsule()
                        .fill(Color.glassFill)
                        .overlay(Capsule().stroke(Color.glassBorder, lineWidth: 1))
                )
            }
        }
    }
}

extension View {
    func capsuleGlass(shadow: Bool = false, interactive: Bool = false) -> some View {
        modifier(CapsuleGlassModifier(shadow: shadow, interactive: interactive))
    }
}
