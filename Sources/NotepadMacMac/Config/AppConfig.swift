import Foundation

/// Global app configuration.
struct AppConfig {
    static let appName = "NotepadMacMac"
    static let bundleIdentifier = "com.notepadmacmac.app"
    static let version = "1.1.0"

    static var configDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(appName)
    }

    static func ensureConfigDirectory() {
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
