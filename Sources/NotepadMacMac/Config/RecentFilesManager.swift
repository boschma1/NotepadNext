import Foundation

/// Manages a list of recently opened files, persisted across launches.
class RecentFilesManager {

    static let shared = RecentFilesManager()

    private let defaults = UserDefaults.standard
    private let key = "NNRecentFiles"
    private let maxItems = 15

    private(set) var recentFiles: [URL] = []

    init() {
        load()
    }

    func addFile(_ url: URL) {
        // Remove if already in list (will re-add at top)
        recentFiles.removeAll { $0.path == url.path }
        // Insert at top
        recentFiles.insert(url, at: 0)
        // Trim to max
        if recentFiles.count > maxItems {
            recentFiles = Array(recentFiles.prefix(maxItems))
        }
        save()
    }

    func clear() {
        recentFiles.removeAll()
        save()
    }

    private func load() {
        guard let paths = defaults.stringArray(forKey: key) else { return }
        recentFiles = paths.map { URL(fileURLWithPath: $0) }
    }

    private func save() {
        defaults.set(recentFiles.map { $0.path }, forKey: key)
    }
}
