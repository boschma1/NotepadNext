import Foundation

/// Saves and restores the list of open files between app launches.
class SessionManager {

    static let shared = SessionManager()

    private var sessionURL: URL {
        let dir = AppConfig.configDirectory
        return dir.appendingPathComponent("session.json")
    }

    struct SessionData: Codable {
        struct FileEntry: Codable {
            let path: String
            let language: String
            let cursorPosition: Int
        }
        var files: [FileEntry]
        var activeIndex: Int
    }

    func saveSession(from documentManager: DocumentManager) {
        AppConfig.ensureConfigDirectory()

        let entries = documentManager.documents.compactMap { doc -> SessionData.FileEntry? in
            guard let url = doc.fileURL else { return nil }
            return SessionData.FileEntry(
                path: url.path,
                language: doc.language,
                cursorPosition: doc.cursorPosition
            )
        }

        let activeIdx = documentManager.activeIndex
        let session = SessionData(files: entries, activeIndex: min(activeIdx, entries.count - 1))

        do {
            let data = try JSONEncoder().encode(session)
            try data.write(to: sessionURL, options: .atomic)
        } catch {
            print("Failed to save session: \(error)")
        }
    }

    func restoreSession(into documentManager: DocumentManager) {
        guard FileManager.default.fileExists(atPath: sessionURL.path) else { return }

        do {
            let data = try Data(contentsOf: sessionURL)
            let session = try JSONDecoder().decode(SessionData.self, from: data)

            var restoredAny = false
            for entry in session.files {
                let url = URL(fileURLWithPath: entry.path)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                if let doc = documentManager.openDocument(at: url) {
                    doc.language = entry.language
                    doc.cursorPosition = entry.cursorPosition
                    restoredAny = true
                }
            }

            if restoredAny && session.activeIndex >= 0 && session.activeIndex < documentManager.documents.count {
                documentManager.switchToDocument(at: session.activeIndex)
            }
        } catch {
            print("Failed to restore session: \(error)")
        }
    }
}
