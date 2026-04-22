import SwiftUI

/// Dark/Light adaptive tokens — ported from ShowSync. Figma variables in `Semantic` collection map here.
extension Color {
    static let bgBackground   = Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor.black : UIColor.white })
    static let bgSurface      = Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor(white: 0.08, alpha: 1) : UIColor(white: 0.98, alpha: 1) })
    static let textPrimary    = Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor.white : UIColor.black })
    static let textSecondary  = Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor(white: 0.75, alpha: 1) : UIColor(white: 0.4, alpha: 1) })
    static let glassFill      = Color.white.opacity(0.08)
    static let glassBorder    = Color.white.opacity(0.14)

    static let resultWin  = Color.green
    static let resultDraw = Color.gray
    static let resultLoss = Color.red
}
