import Foundation

/// Global app configuration.
struct AppConfig {
    static let appName = "NotepadMacMac"
    static let bundleIdentifier = "com.notepadmacmac.app"
    static let version = "1.1.2"

    static var configDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(appName)
    }

    static func ensureConfigDirectory() {
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    }
}

/// Lightweight user-defaults-backed editor view settings.
enum EditorSettings {
    private static let showFormattingMarksKey = "NMM_ShowFormattingMarks"

    static var showFormattingMarks: Bool {
        get { UserDefaults.standard.bool(forKey: showFormattingMarksKey) }
        set { UserDefaults.standard.set(newValue, forKey: showFormattingMarksKey) }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
