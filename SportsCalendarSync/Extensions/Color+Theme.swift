import SwiftUI

extension Color {
    // MARK: - Backgrounds
    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1)       // #0A0A0A
            : UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1)       // #F7F7F7
    })
    static let surface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)       // #1C1C1E
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)          // #FFFFFF
    })
    static let surfaceElevated = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1)       // #2C2C2E
            : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)       // #F2F2F7
    })
    static let border = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1)       // #38383C
            : UIColor(red: 0.78, green: 0.78, blue: 0.80, alpha: 1)       // #C7C7CC
    })

    // MARK: - Text
    static let textPrimary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
    })
    static let textSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.6, alpha: 1)
            : UIColor(white: 0.4, alpha: 1)
    })
    static let textTertiary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.4, alpha: 1)
            : UIColor(white: 0.6, alpha: 1)
    })

    // MARK: - Semantic
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .black
    })
    static let success = Color(red: 0.19, green: 0.82, blue: 0.35)          // #30D158
    static let danger = Color(red: 1.0, green: 0.27, blue: 0.23)            // #FF453A

    // Sports-specific — match/result colors used in form rows and chips
    static let resultWin  = Color.success
    static let resultDraw = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.55, alpha: 1)
            : UIColor(white: 0.45, alpha: 1)
    })
    static let resultLoss = Color.danger

    // MARK: - Glass materials (floating nav, segmented filter)
    static let glassFill = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.0, alpha: 0.75)
            : UIColor(white: 1.0, alpha: 0.85)
    })
    static let glassBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.15)
            : UIColor(white: 0.0, alpha: 0.08)
    })
    static let glassShadow = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.0, alpha: 0.70)
            : UIColor(white: 0.0, alpha: 0.12)
    })
    static let glassHighlight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.15)
            : UIColor(white: 0.0, alpha: 0.08)
    })
}

extension ShapeStyle where Self == Color {
    static var success: Color { Color.success }
    static var danger: Color { Color.danger }
    static var background: Color { Color.background }
    static var surface: Color { Color.surface }
    static var surfaceElevated: Color { Color.surfaceElevated }
    static var border: Color { Color.border }
    static var textPrimary: Color { Color.textPrimary }
    static var textSecondary: Color { Color.textSecondary }
    static var textTertiary: Color { Color.textTertiary }
    static var glassFill: Color { Color.glassFill }
    static var glassBorder: Color { Color.glassBorder }
    static var glassShadow: Color { Color.glassShadow }
    static var glassHighlight: Color { Color.glassHighlight }
    static var resultWin: Color { Color.resultWin }
    static var resultDraw: Color { Color.resultDraw }
    static var resultLoss: Color { Color.resultLoss }
}

extension Color {
    /// Accepts "RRGGBB" or "#RRGGBB". Returns nil on invalid input.
    init?(hex: String?) {
        guard let raw = hex?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let cleaned = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
