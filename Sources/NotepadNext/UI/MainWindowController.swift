import AppKit

class MainWindowController: NSWindowController {

    let documentManager = DocumentManager()
    private(set) var editorCommands: EditorCommands?

    private var tabBarView: TabBarView!
    private var editorView: EditorView!
    private var statusBarView: StatusBarView!
    private var contentView: NSView!
    private var findReplaceController: FindReplaceWindowController?
    private var goToLineController: GoToLineWindowController?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "NotepadNext"
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)

        self.init(window: window)
        setupUI()
        documentManager.delegate = self
        documentManager.createNewDocument()
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let window = window else { return }

        contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        // Tab bar
        tabBarView = TabBarView()
        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        tabBarView.delegate = self
        contentView.addSubview(tabBarView)

        // Editor
        editorView = EditorView()
        editorView.translatesAutoresizingMaskIntoConstraints = false
        editorView.delegate = self
        editorCommands = EditorCommands(textView: editorView.textView)
        contentView.addSubview(editorView)

        // Status bar
        statusBarView = StatusBarView()
        statusBarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusBarView)

        NSLayoutConstraint.activate([
            tabBarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tabBarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tabBarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            editorView.topAnchor.constraint(equalTo: tabBarView.bottomAnchor),
            editorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            editorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            editorView.bottomAnchor.constraint(equalTo: statusBarView.topAnchor),

            statusBarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    // MARK: - File Actions

    func saveCurrentDocument() {
        guard let doc = documentManager.activeDocument else { return }
        doc.content = editorView.text

        if doc.fileURL == nil {
            saveCurrentDocumentAs()
            return
        }

        do {
            try doc.save()
            updateTabTitle(for: doc)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func saveCurrentDocumentAs() {
        guard let doc = documentManager.activeDocument,
              let window = window else { return }

        doc.content = editorView.text

        let panel = NSSavePanel()
        panel.nameFieldStringValue = doc.title
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try doc.save(to: url)
                self?.window?.title = "NotepadNext — \(doc.title)"
                self?.updateTabTitle(for: doc)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    func closeCurrentTab() {
        let index = documentManager.activeIndex
        guard index >= 0 else { return }
        _ = documentManager.closeDocument(at: index)
    }

    func showFindReplace() {
        if findReplaceController == nil {
            findReplaceController = FindReplaceWindowController(textView: editorView.textView)
        }
        findReplaceController?.showAndFocus()
    }

    func showGoToLine() {
        if goToLineController == nil {
            goToLineController = GoToLineWindowController(textView: editorView.textView)
        }
        goToLineController?.showAndFocus()
    }

    func setLanguage(_ language: String) {
        guard let doc = documentManager.activeDocument else { return }
        doc.language = language
        editorView.language = language
        // Re-highlight by triggering a text storage edit
        if let ts = editorView.textView.textStorage {
            ts.beginEditing()
            ts.endEditing()
        }
        updateStatusBar(for: doc)
        if let index = documentManager.documents.firstIndex(where: { $0.id == doc.id }) {
            documentManager.delegate?.documentManager(documentManager, didUpdateDocument: doc, at: index)
        }
    }

    // MARK: - Helpers

    private func loadDocumentIntoEditor(_ doc: Document) {
        editorView.language = doc.language
        editorView.text = doc.content
        updateStatusBar(for: doc)
        let title = doc.fileURL?.path ?? doc.title
        window?.title = "NotepadNext — \(title)"
    }

    private func updateStatusBar(for doc: Document) {
        let text = editorView.text
        let lines = text.components(separatedBy: .newlines).count

        // Calculate cursor position
        let selectedRange = editorView.textView.selectedRange()
        let textUpToCursor = (text as NSString).substring(to: selectedRange.location)
        let currentLineComponents = textUpToCursor.components(separatedBy: .newlines)
        let line = currentLineComponents.count
        let col = (currentLineComponents.last?.count ?? 0) + 1

        let encodingName: String
        switch doc.encoding {
        case .utf8: encodingName = "UTF-8"
        case .utf16: encodingName = "UTF-16"
        case .ascii: encodingName = "ASCII"
        default: encodingName = "ANSI"
        }

        statusBarView.update(
            line: line, column: col,
            length: text.count, lines: lines,
            encoding: encodingName,
            lineEnding: doc.lineEnding.rawValue,
            language: doc.language
        )
    }

    private func updateTabTitle(for doc: Document) {
        guard let index = documentManager.documents.firstIndex(where: { $0.id == doc.id }) else { return }
        tabBarView.updateTab(at: index, title: doc.displayTitle, isModified: doc.isModified)
    }
}

// MARK: - DocumentManagerDelegate

extension MainWindowController: DocumentManagerDelegate {
    func documentManager(_ manager: DocumentManager, didAddDocument document: Document, at index: Int) {
        let tab = TabBarView.Tab(id: document.id, title: document.displayTitle, isModified: document.isModified)
        tabBarView.addTab(tab)
    }

    func documentManager(_ manager: DocumentManager, didRemoveDocumentAt index: Int) {
        tabBarView.removeTab(at: index)
    }

    func documentManager(_ manager: DocumentManager, didSwitchToDocument document: Document, at index: Int) {
        tabBarView.selectTab(at: index)
        loadDocumentIntoEditor(document)
    }

    func documentManager(_ manager: DocumentManager, didUpdateDocument document: Document, at index: Int) {
        tabBarView.updateTab(at: index, title: document.displayTitle, isModified: document.isModified)
    }
}

// MARK: - TabBarViewDelegate

extension MainWindowController: TabBarViewDelegate {
    func tabBarView(_ tabBar: TabBarView, didSelectTabAt index: Int) {
        // Save current text before switching
        if let doc = documentManager.activeDocument {
            doc.content = editorView.text
        }
        documentManager.switchToDocument(at: index)
    }

    func tabBarView(_ tabBar: TabBarView, didCloseTabAt index: Int) {
        // Save current text before potentially closing
        if let doc = documentManager.activeDocument {
            doc.content = editorView.text
        }
        _ = documentManager.closeDocument(at: index)
    }

    func tabBarViewDidRequestNewTab(_ tabBar: TabBarView) {
        if let doc = documentManager.activeDocument {
            doc.content = editorView.text
        }
        documentManager.createNewDocument()
    }
}

// MARK: - EditorViewDelegate

extension MainWindowController: EditorViewDelegate {
    func editorViewDidChange(_ editorView: EditorView) {
        guard let doc = documentManager.activeDocument else { return }
        documentManager.updateContent(for: doc, content: editorView.text)
        updateStatusBar(for: doc)
    }
}
