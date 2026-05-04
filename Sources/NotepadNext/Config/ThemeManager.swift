import AppKit

/// Manages theme switching between light and dark modes.
class ThemeManager {

    static let shared = ThemeManager()

    enum Theme: String {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        case monokai = "Monokai"
        case solarizedDark = "Solarized Dark"
    }

    var currentTheme: Theme = .system {
        didSet { applyTheme() }
    }

    func applyTheme() {
        switch currentTheme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .monokai:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .solarizedDark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func syntaxTheme(for theme: Theme) -> SyntaxTheme {
        switch theme {
        case .system:
            if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return .dark
            }
            return .defaultLight
        case .light:
            return .defaultLight
        case .dark, .monokai, .solarizedDark:
            return .dark
        }
    }

    var activeSyntaxTheme: SyntaxTheme {
        return syntaxTheme(for: currentTheme)
    }
}
