import AppKit
import Foundation

/// Global app configuration.
struct AppConfig {
    static let appName = "NotepadMacMac"
    static let bundleIdentifier = "com.notepadmacmac.app"
    static let version = "1.2.0"

    static var configDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(appName)
    }

    static func ensureConfigDirectory() {
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    }
}

extension Notification.Name {
    /// Posted when the user changes the appearance style or its transparency
    /// level. Listeners (the main window controller) should re-apply the
    /// current appearance.
    static let nmmAppearanceDidChange = Notification.Name("NMMAppearanceDidChange")
}

/// Lightweight user-defaults-backed editor view settings.
enum EditorSettings {
    private static let showFormattingMarksKey = "NMM_ShowFormattingMarks"
    private static let appearanceStyleKey = "NMM_AppearanceStyle"
    private static let transparencyAlphaKey = "NMM_TransparencyAlpha"

    static let defaultTransparencyAlpha: CGFloat = 0.90
    static let minTransparencyAlpha: CGFloat = 0.30
    static let maxTransparencyAlpha: CGFloat = 1.00

    static var showFormattingMarks: Bool {
        get { UserDefaults.standard.bool(forKey: showFormattingMarksKey) }
        set { UserDefaults.standard.set(newValue, forKey: showFormattingMarksKey) }
    }

    static var appearanceStyle: AppearanceStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: appearanceStyleKey),
                  let value = AppearanceStyle(rawValue: raw)
            else { return .standard }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: appearanceStyleKey) }
    }

    /// Opacity used in transparency mode (1.0 = fully opaque, 0.30 = very see-through).
    static var transparencyAlpha: CGFloat {
        get {
            let raw = UserDefaults.standard.object(forKey: transparencyAlphaKey) as? Double
            let value = raw.map { CGFloat($0) } ?? defaultTransparencyAlpha
            return min(max(value, minTransparencyAlpha), maxTransparencyAlpha)
        }
        set {
            let clamped = min(max(newValue, minTransparencyAlpha), maxTransparencyAlpha)
            UserDefaults.standard.set(Double(clamped), forKey: transparencyAlphaKey)
        }
    }
}

/// Window-chrome appearance style. Independent of the colour theme.
enum AppearanceStyle: String, CaseIterable {
    case standard       // opaque window, theme background as-is
    case transparency   // clear window, desktop visible through editor (no blur)

    var displayName: String {
        switch self {
        case .standard:     return "Standard"
        case .transparency: return "Transparency"
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
