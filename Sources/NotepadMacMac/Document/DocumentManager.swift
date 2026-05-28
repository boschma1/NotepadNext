import AppKit

protocol DocumentManagerDelegate: AnyObject {
    func documentManager(_ manager: DocumentManager, didAddDocument document: Document, at index: Int)
    func documentManager(_ manager: DocumentManager, didRemoveDocumentAt index: Int)
    func documentManager(_ manager: DocumentManager, didSwitchToDocument document: Document, at index: Int)
    func documentManager(_ manager: DocumentManager, didUpdateDocument document: Document, at index: Int)
    func documentManager(_ manager: DocumentManager, didDetectExternalChangeFor document: Document, wasDeleted: Bool)
}

extension DocumentManagerDelegate {
    func documentManager(_ manager: DocumentManager, didDetectExternalChangeFor document: Document, wasDeleted: Bool) {}
}

class DocumentManager {

    weak var delegate: DocumentManagerDelegate?

    private(set) var documents: [Document] = []
    private(set) var activeIndex: Int = -1
    private var newDocCounter = 1
    private var watchers: [UUID: FileChangeWatcher] = [:]

    var activeDocument: Document? {
        guard activeIndex >= 0, activeIndex < documents.count else { return nil }
        return documents[activeIndex]
    }

    // MARK: - Document lifecycle

    @discardableResult
    func createNewDocument() -> Document {
        let doc = Document(title: "new \(newDocCounter)")
        newDocCounter += 1
        addDocument(doc)
        return doc
    }

    @discardableResult
    func openDocument(at url: URL) -> Document? {
        // If already open, just switch to it
        if let existingIndex = documents.firstIndex(where: { $0.fileURL == url }) {
            switchToDocument(at: existingIndex)
            return documents[existingIndex]
        }

        let doc = Document(title: url.lastPathComponent, fileURL: url)
        do {
            try doc.load()
            doc.language = detectLanguage(for: url)
            addDocument(doc)
            RecentFilesManager.shared.addFile(url)
            startWatching(doc)
            return doc
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
    }

    /// Save `doc` (optionally to a new `url`) and refresh its file watcher
    /// so that the post-save inode is what we monitor going forward.
    func saveDocument(_ doc: Document, to url: URL? = nil) throws {
        try doc.save(to: url)
        startWatching(doc)
        if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
            delegate?.documentManager(self, didUpdateDocument: doc, at: idx)
        }
    }

    func closeDocument(at index: Int) -> Bool {
        guard index >= 0, index < documents.count else { return false }

        let doc = documents[index]
        if doc.isModified && !doc.content.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Save changes to \"\(doc.title)\"?"
            alert.informativeText = "Your changes will be lost if you don't save them."
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()

            switch response {
            case .alertFirstButtonReturn:
                do {
                    try saveDocument(doc)
                } catch {
                    NSAlert(error: error).runModal()
                    return false
                }
            case .alertThirdButtonReturn:
                return false
            default:
                break
            }
        }

        stopWatching(doc)
        documents.remove(at: index)
        delegate?.documentManager(self, didRemoveDocumentAt: index)

        if documents.isEmpty {
            activeIndex = -1
            NSApp.terminate(nil)
        } else {
            let newIndex = min(index, documents.count - 1)
            switchToDocument(at: newIndex)
        }
        return true
    }

    func switchToDocument(at index: Int) {
        guard index >= 0, index < documents.count else { return }
        activeIndex = index
        delegate?.documentManager(self, didSwitchToDocument: documents[index], at: index)
    }

    func notifyDocumentModified(_ document: Document) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        document.isModified = true
        delegate?.documentManager(self, didUpdateDocument: document, at: index)
    }

    func updateContent(for document: Document, content: String) {
        document.content = content
        if !document.isModified {
            document.isModified = true
            if let index = documents.firstIndex(where: { $0.id == document.id }) {
                delegate?.documentManager(self, didUpdateDocument: document, at: index)
            }
        }
    }

    // MARK: - Private

    private func addDocument(_ doc: Document) {
        documents.append(doc)
        let index = documents.count - 1
        delegate?.documentManager(self, didAddDocument: doc, at: index)
        switchToDocument(at: index)
    }

    // MARK: - External file watching

    /// Begin (or refresh) watching `doc`'s backing file. Has no effect
    /// for unsaved documents that don't have a `fileURL` yet.
    private func startWatching(_ doc: Document) {
        guard let url = doc.fileURL else {
            stopWatching(doc)
            return
        }
        let docID = doc.id
        let watcher = FileChangeWatcher { [weak self, weak doc] in
            guard let self, let doc, doc.id == docID,
                  self.documents.contains(where: { $0.id == docID }),
                  let url = doc.fileURL else { return }

            let currentSignature = Document.diskSignature(of: url)

            if currentSignature == nil {
                // File no longer exists on disk. Don't clear
                // doc.lastKnownDiskSignature here — let the dialog
                // completion handler do it after the user
                // acknowledges. That way processPendingExternalChanges
                // can still derive `wasDeleted` from a fresh stat and
                // de-dupe redundant events.
                guard doc.lastKnownDiskSignature != nil else { return }
                self.delegate?.documentManager(self, didDetectExternalChangeFor: doc, wasDeleted: true)
                return
            }

            // Same signature as the last load/save we performed → it
            // was our own write that triggered the event; ignore.
            if currentSignature == doc.lastKnownDiskSignature {
                return
            }

            self.delegate?.documentManager(self, didDetectExternalChangeFor: doc, wasDeleted: false)
        }
        watcher.start(url: url)
        watchers[doc.id] = watcher
    }

    private func stopWatching(_ doc: Document) {
        if let watcher = watchers.removeValue(forKey: doc.id) {
            watcher.stop()
        }
    }

    private func detectLanguage(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        let languageMap: [String: String] = [
            "swift": "Swift", "py": "Python", "js": "JavaScript", "ts": "TypeScript",
            "java": "Java", "c": "C", "cpp": "C++", "h": "C", "hpp": "C++",
            "cs": "C#", "rb": "Ruby", "go": "Go", "rs": "Rust",
            "html": "HTML", "htm": "HTML", "css": "CSS", "xml": "XML",
            "json": "JSON", "yaml": "YAML", "yml": "YAML", "toml": "TOML",
            "md": "Markdown", "sh": "Shell", "bash": "Shell", "zsh": "Shell",
            "sql": "SQL", "php": "PHP", "r": "R", "lua": "Lua",
            "pl": "Perl", "m": "Objective-C", "mm": "Objective-C++",
            "kt": "Kotlin", "scala": "Scala", "dart": "Dart",
            "txt": "Normal Text", "log": "Normal Text", "ini": "INI",
            "makefile": "Makefile", "cmake": "CMake",
        ]
        return languageMap[ext] ?? "Normal Text"
    }
}
