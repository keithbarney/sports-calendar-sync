import SwiftUI
import UIKit

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Lucide name (unused in Settings but kept for parity with ShowSync).
    var icon: String {
        switch self {
        case .system: return "contrast"
        case .light: return "sun"
        case .dark: return "moon"
        }
    }

    var sfSymbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

/// Sports equivalent of ShowSync's `EpisodeReminder` / `MovieReminder`. Controls when
/// the calendar event's alarm fires before kickoff.
enum KickoffReminder: String, CaseIterable {
    case fifteenMin = "15 min before"
    case thirtyMin  = "30 min before"
    case oneHour    = "1 hour before"
    case dayBefore  = "Day before"
    case off        = "Off"

    var sfSymbol: String {
        switch self {
        case .fifteenMin, .thirtyMin, .oneHour: return "clock"
        case .dayBefore: return "calendar"
        case .off: return "bell.slash"
        }
    }

    var offsetSeconds: TimeInterval? {
        switch self {
        case .fifteenMin: return -900
        case .thirtyMin:  return -1800
        case .oneHour:    return -3600
        case .dayBefore:  return -86400
        case .off:        return nil
        }
    }
}

final class AppSettings: ObservableObject {
    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .system {
        didSet { applyAppearance() }
    }
    @AppStorage("kickoffReminder") var kickoffReminder: KickoffReminder = .thirtyMin

    init() { applyAppearance() }

    func applyAppearance() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }
        window.overrideUserInterfaceStyle = appearanceMode.userInterfaceStyle
    }
}

// MARK: - Bundle helpers (parity with ShowSync)

extension Bundle {
    var marketingVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}
