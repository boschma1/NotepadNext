import AppKit

/// Full editor theme: fonts, colors, and syntax highlighting.
class ThemeManager {

    static let shared = ThemeManager()

    /// All available built-in themes
    static let builtInThemes: [EditorTheme] = [
        EditorTheme(
            name: "Default Light",
            appearance: .light,
            editorFont: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            uiFont: NSFont.systemFont(ofSize: 13),
            foreground: NSColor.black,
            background: NSColor.white,
            lineHighlight: NSColor(white: 0.95, alpha: 1),
            selectionBg: NSColor.selectedTextBackgroundColor,
            gutterBg: NSColor(white: 0.96, alpha: 1),
            gutterFg: NSColor.secondaryLabelColor,
            caretColor: NSColor.black,
            syntax: SyntaxTheme.defaultLight
        ),
        EditorTheme(
            name: "Default Dark",
            appearance: .dark,
            editorFont: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            uiFont: NSFont.systemFont(ofSize: 13),
            foreground: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),
            background: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1),
            lineHighlight: NSColor(white: 0.18, alpha: 1),
            selectionBg: NSColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 1),
            gutterBg: NSColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1),
            gutterFg: NSColor(white: 0.45, alpha: 1),
            caretColor: NSColor.white,
            syntax: SyntaxTheme.dark
        ),
        EditorTheme(
            name: "Monokai",
            appearance: .dark,
            editorFont: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            uiFont: NSFont.systemFont(ofSize: 13),
            foreground: NSColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1),
            background: NSColor(red: 0.15, green: 0.16, blue: 0.13, alpha: 1),
            lineHighlight: NSColor(red: 0.20, green: 0.21, blue: 0.17, alpha: 1),
            selectionBg: NSColor(red: 0.28, green: 0.30, blue: 0.24, alpha: 1),
            gutterBg: NSColor(red: 0.15, green: 0.16, blue: 0.13, alpha: 1),
            gutterFg: NSColor(white: 0.50, alpha: 1),
            caretColor: NSColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1),
            syntax: SyntaxTheme(
                defaultColor: NSColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1),
                keywordColor: NSColor(red: 0.98, green: 0.15, blue: 0.45, alpha: 1),
                stringColor: NSColor(red: 0.90, green: 0.86, blue: 0.45, alpha: 1),
                commentColor: NSColor(red: 0.46, green: 0.44, blue: 0.36, alpha: 1),
                numberColor: NSColor(red: 0.68, green: 0.51, blue: 1.0, alpha: 1),
                typeColor: NSColor(red: 0.40, green: 0.85, blue: 0.94, alpha: 1),
                preprocessorColor: NSColor(red: 0.68, green: 0.51, blue: 1.0, alpha: 1),
                operatorColor: NSColor(red: 0.98, green: 0.15, blue: 0.45, alpha: 1)
            )
        ),
        EditorTheme(
            name: "Solarized Light",
            appearance: .light,
            editorFont: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            uiFont: NSFont.systemFont(ofSize: 13),
            foreground: NSColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 1),
            background: NSColor(red: 0.99, green: 0.96, blue: 0.89, alpha: 1),
            lineHighlight: NSColor(red: 0.93, green: 0.91, blue: 0.84, alpha: 1),
            selectionBg: NSColor(red: 0.93, green: 0.91, blue: 0.84, alpha: 1),
            gutterBg: NSColor(red: 0.93, green: 0.91, blue: 0.84, alpha: 1),
            gutterFg: NSColor(red: 0.58, green: 0.63, blue: 0.63, alpha: 1),
            caretColor: NSColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 1),
            syntax: SyntaxTheme(
                defaultColor: NSColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 1),
                keywordColor: NSColor(red: 0.52, green: 0.60, blue: 0.0, alpha: 1),
                stringColor: NSColor(red: 0.16, green: 0.63, blue: 0.60, alpha: 1),
                commentColor: NSColor(red: 0.58, green: 0.63, blue: 0.63, alpha: 1),
                numberColor: NSColor(red: 0.80, green: 0.29, blue: 0.09, alpha: 1),
                typeColor: NSColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1),
                preprocessorColor: NSColor(red: 0.83, green: 0.21, blue: 0.51, alpha: 1),
                operatorColor: NSColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 1)
            )
        ),
        EditorTheme(
            name: "Solarized Dark",
            appearance: .dark,
            editorFont: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            uiFont: NSFont.systemFont(ofSize: 13),
            foreground: NSColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1),
            background: NSColor(red: 0.0, green: 0.17, blue: 0.21, alpha: 1),
            lineHighlight: NSColor(red: 0.03, green: 0.21, blue: 0.26, alpha: 1),
            selectionBg: NSColor(red: 0.03, green: 0.21, blue: 0.26, alpha: 1),
            gutterBg: NSColor(red: 0.0, green: 0.17, blue: 0.21, alpha: 1),
            gutterFg: NSColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 1),
            caretColor: NSColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1),
            syntax: SyntaxTheme(
                defaultColor: NSColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1),
                keywordColor: NSColor(red: 0.52, green: 0.60, blue: 0.0, alpha: 1),
                stringColor: NSColor(red: 0.16, green: 0.63, blue: 0.60, alpha: 1),
                commentColor: NSColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 1),
                numberColor: NSColor(red: 0.80, green: 0.29, blue: 0.09, alpha: 1),
                typeColor: NSColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1),
                preprocessorColor: NSColor(red: 0.83, green: 0.21, blue: 0.51, alpha: 1),
                operatorColor: NSColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1)
            )
        ),
        EditorTheme(
            name: "GitHub Light",
            appearance: .light,
            editorFont: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            uiFont: NSFont.systemFont(ofSize: 13),
            foreground: NSColor(red: 0.14, green: 0.16, blue: 0.19, alpha: 1),
            background: NSColor.white,
            lineHighlight: NSColor(red: 1.0, green: 0.98, blue: 0.91, alpha: 1),
            selectionBg: NSColor(red: 0.68, green: 0.84, blue: 1.0, alpha: 1),
            gutterBg: NSColor.white,
            gutterFg: NSColor(red: 0.73, green: 0.77, blue: 0.82, alpha: 1),
            caretColor: NSColor(red: 0.14, green: 0.16, blue: 0.19, alpha: 1),
            syntax: SyntaxTheme(
                defaultColor: NSColor(red: 0.14, green: 0.16, blue: 0.19, alpha: 1),
                keywordColor: NSColor(red: 0.82, green: 0.10, blue: 0.27, alpha: 1),
                stringColor: NSColor(red: 0.02, green: 0.37, blue: 0.67, alpha: 1),
                commentColor: NSColor(red: 0.42, green: 0.47, blue: 0.53, alpha: 1),
                numberColor: NSColor(red: 0.02, green: 0.37, blue: 0.67, alpha: 1),
                typeColor: NSColor(red: 0.38, green: 0.28, blue: 0.61, alpha: 1),
                preprocessorColor: NSColor(red: 0.82, green: 0.10, blue: 0.27, alpha: 1),
                operatorColor: NSColor(red: 0.14, green: 0.16, blue: 0.19, alpha: 1)
            )
        ),
    ]

    private var _currentTheme: EditorTheme = builtInThemes[0]

    var currentTheme: EditorTheme {
        get { _currentTheme }
        set {
            _currentTheme = newValue
            applyTheme()
            saveSettings()
        }
    }

    /// Callback for when the theme changes so the editor can update.
    var onThemeChanged: ((EditorTheme) -> Void)?

    func applyTheme() {
        switch _currentTheme.appearance {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        onThemeChanged?(_currentTheme)
    }

    // MARK: - Persistence

    private let defaults = UserDefaults.standard
    private let kThemeName = "NNThemeName"
    private let kEditorFontName = "NNEditorFontName"
    private let kEditorFontSize = "NNEditorFontSize"
    private let kUIFontName = "NNUIFontName"
    private let kUIFontSize = "NNUIFontSize"
    private let kForeground = "NNForeground"
    private let kBackground = "NNBackground"

    func loadSettings() {
        // Build the theme without triggering didSet/saveSettings
        var theme = ThemeManager.builtInThemes[0]

        if let name = defaults.string(forKey: kThemeName),
           let base = ThemeManager.builtInThemes.first(where: { $0.name == name }) {
            theme = base
        }

        if let fontName = defaults.string(forKey: kEditorFontName) {
            let size = defaults.double(forKey: kEditorFontSize)
            if let font = NSFont(name: fontName, size: size > 0 ? size : 13) {
                theme.editorFont = font
            }
        }
        if let fontName = defaults.string(forKey: kUIFontName) {
            let size = defaults.double(forKey: kUIFontSize)
            if let font = NSFont(name: fontName, size: size > 0 ? size : 13) {
                theme.uiFont = font
            }
        }

        if let fgData = defaults.data(forKey: kForeground),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: fgData) {
            theme.foreground = color
        }
        if let bgData = defaults.data(forKey: kBackground),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: bgData) {
            theme.background = color
        }

        // Set directly without triggering save
        _currentTheme = theme
    }

    func saveSettings() {
        defaults.set(currentTheme.name, forKey: kThemeName)
        defaults.set(currentTheme.editorFont.fontName, forKey: kEditorFontName)
        defaults.set(Double(currentTheme.editorFont.pointSize), forKey: kEditorFontSize)
        defaults.set(currentTheme.uiFont.fontName, forKey: kUIFontName)
        defaults.set(Double(currentTheme.uiFont.pointSize), forKey: kUIFontSize)

        if let fgData = try? NSKeyedArchiver.archivedData(withRootObject: currentTheme.foreground, requiringSecureCoding: false) {
            defaults.set(fgData, forKey: kForeground)
        }
        if let bgData = try? NSKeyedArchiver.archivedData(withRootObject: currentTheme.background, requiringSecureCoding: false) {
            defaults.set(bgData, forKey: kBackground)
        }
    }
}

/// Complete editor theme definition.
struct EditorTheme {
    enum Appearance { case light, dark }

    let name: String
    let appearance: Appearance
    var editorFont: NSFont
    var uiFont: NSFont
    var foreground: NSColor
    var background: NSColor
    var lineHighlight: NSColor
    var selectionBg: NSColor
    var gutterBg: NSColor
    var gutterFg: NSColor
    var caretColor: NSColor
    var syntax: SyntaxTheme
}
