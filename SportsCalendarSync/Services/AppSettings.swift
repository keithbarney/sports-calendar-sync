import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("appearanceMode") var appearanceModeRaw: String = AppearanceMode.dark.rawValue

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .dark }
        set { appearanceModeRaw = newValue.rawValue; applyAppearance() }
    }

    func applyAppearance() {
        let style: UIUserInterfaceStyle = {
            switch appearanceMode {
            case .system: return .unspecified
            case .light:  return .light
            case .dark:   return .dark
            }
        }()
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
