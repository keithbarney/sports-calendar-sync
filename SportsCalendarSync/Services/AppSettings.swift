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

/// Debug review scenarios are named in one shared type so the app's model
/// factory can keep its production signature compilable in Release builds.
enum MockReviewScenario: String, CaseIterable, Identifiable {
    case typical = "Typical library"
    case empty = "Empty library"
    case datesPending = "Dates pending"
    case syncFailure = "Sync failure"
    case longTitles = "Long titles"

    var id: String { rawValue }
}

@MainActor
final class AppSettings: ObservableObject {
    static let mockSuiteName = "SportsCalendarSync.mock.preferences"

    /// Mock and screenshot runs keep mutable review settings in their own suite.
    /// This prevents a capture appearance or reminder choice from becoming the
    /// user's setting on the next normal launch.
    static func preferenceDefaults(isMock: Bool? = nil) -> UserDefaults {
        #if DEBUG
        let useMock = isMock ?? ScreenshotFixtures.isEnabled
        if useMock {
            return UserDefaults(suiteName: mockSuiteName)!
        }
        #endif
        return .standard
    }

    private let defaults: UserDefaults
    private var isInitializing = true

    @Published var appearanceMode: AppearanceMode {
        didSet {
            guard !isInitializing else { return }
            defaults.set(appearanceMode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }

    @Published var kickoffReminder: KickoffReminder {
        didSet {
            guard !isInitializing else { return }
            defaults.set(kickoffReminder.rawValue, forKey: "kickoffReminder")
        }
    }

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? Self.preferenceDefaults()
        let storedAppearance = self.defaults.string(forKey: "appearanceMode")
            .flatMap(AppearanceMode.init(rawValue:)) ?? .system
        let storedReminder = self.defaults.string(forKey: "kickoffReminder")
            .flatMap(KickoffReminder.init(rawValue:)) ?? .thirtyMin
        _appearanceMode = Published(initialValue: storedAppearance)
        _kickoffReminder = Published(initialValue: storedReminder)

        #if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "-appearanceMode"),
           index + 1 < CommandLine.arguments.count,
           let mode = AppearanceMode(rawValue: CommandLine.arguments[index + 1]) {
            appearanceMode = mode
            self.defaults.set(mode.rawValue, forKey: "appearanceMode")
        }
        #endif
        isInitializing = false
        applyAppearance()
    }

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
