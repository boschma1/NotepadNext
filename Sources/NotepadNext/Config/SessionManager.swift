import Foundation

/// Saves and restores the list of open files between app launches,
/// including unsaved document content.
class SessionManager {

    static let shared = SessionManager()

    private var sessionURL: URL {
        AppConfig.configDirectory.appendingPathComponent("session.json")
    }

    private var unsavedDir: URL {
        AppConfig.configDirectory.appendingPathComponent("unsaved")
    }

    func hasSession() -> Bool {
        guard FileManager.default.fileExists(atPath: sessionURL.path),
              let data = try? Data(contentsOf: sessionURL),
              let session = try? JSONDecoder().decode(SessionData.self, from: data) else {
            return false
        }
        return !session.files.isEmpty
    }

    struct SessionData: Codable {
        struct FileEntry: Codable {
            let path: String?       // nil for unsaved documents
            let title: String
            let language: String
            let cursorPosition: Int
            let unsavedID: String?  // ID for unsaved content file
        }
        var files: [FileEntry]
        var activeIndex: Int
    }

    func saveSession(from documentManager: DocumentManager) {
        AppConfig.ensureConfigDirectory()
        let fm = FileManager.default
        try? fm.createDirectory(at: unsavedDir, withIntermediateDirectories: true)

        // Clean old unsaved files
        if let oldFiles = try? fm.contentsOfDirectory(at: unsavedDir, includingPropertiesForKeys: nil) {
            for f in oldFiles { try? fm.removeItem(at: f) }
        }

        var entries: [SessionData.FileEntry] = []

        for doc in documentManager.documents {
            var unsavedID: String? = nil

            if !doc.content.isEmpty {
                if doc.fileURL == nil || doc.isModified {
                    // Save unsaved content to a temp file
                    let id = doc.id.uuidString
                    let contentURL = unsavedDir.appendingPathComponent(id + ".txt")
                    try? doc.content.write(to: contentURL, atomically: true, encoding: .utf8)
                    unsavedID = id
                }
            }

            entries.append(SessionData.FileEntry(
                path: doc.fileURL?.path,
                title: doc.title,
                language: doc.language,
                cursorPosition: doc.cursorPosition,
                unsavedID: unsavedID
            ))
        }

        let activeIdx = documentManager.activeIndex
        let session = SessionData(files: entries, activeIndex: min(activeIdx, max(0, entries.count - 1)))

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
                if let path = entry.path {
                    // File-backed document
                    let url = URL(fileURLWithPath: path)
                    if FileManager.default.fileExists(atPath: url.path) {
                        if let doc = documentManager.openDocument(at: url) {
                            doc.language = entry.language
                            doc.cursorPosition = entry.cursorPosition
                            // Restore unsaved modifications
                            if let uid = entry.unsavedID {
                                let contentURL = unsavedDir.appendingPathComponent(uid + ".txt")
                                if let modified = try? String(contentsOf: contentURL, encoding: .utf8) {
                                    doc.content = modified
                                    doc.isModified = true
                                }
                            }
                            restoredAny = true
                        }
                    }
                } else if let uid = entry.unsavedID {
                    // Unsaved document (no file on disk)
                    let contentURL = unsavedDir.appendingPathComponent(uid + ".txt")
                    if let content = try? String(contentsOf: contentURL, encoding: .utf8), !content.isEmpty {
                        let doc = documentManager.createNewDocument()
                        doc.content = content
                        doc.language = entry.language
                        doc.isModified = true
                        restoredAny = true
                    }
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
