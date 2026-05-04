import Foundation

/// Global app configuration.
struct AppConfig {
    static let appName = "NotepadNext"
    static let bundleIdentifier = "com.notepadnext.app"
    static let version = "0.1.0"

    static var configDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(appName)
    }

    static func ensureConfigDirectory() {
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    }
}
