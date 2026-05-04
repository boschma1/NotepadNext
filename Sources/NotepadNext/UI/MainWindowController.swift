import AppKit

class MainWindowController: NSWindowController {

    let documentManager = DocumentManager()
    private(set) var editorCommands: EditorCommands?

    private var tabBarView: TabBarView!
    private var editorView: EditorView!
    private var statusBarView: StatusBarView!
    private var findReplaceController: FindReplaceWindowController?
    private var goToLineController: GoToLineWindowController?

    func setupContent() {
        guard let contentView = window?.contentView else { return }

        let bounds = contentView.bounds
        let tabBarHeight: CGFloat = 30
        let statusBarHeight: CGFloat = 22

        tabBarView = TabBarView(frame: NSRect(
            x: 0, y: bounds.height - tabBarHeight,
            width: bounds.width, height: tabBarHeight
        ))
        tabBarView.autoresizingMask = [.width, .minYMargin]
        tabBarView.delegate = self
        contentView.addSubview(tabBarView)

        statusBarView = StatusBarView(frame: NSRect(
            x: 0, y: 0,
            width: bounds.width, height: statusBarHeight
        ))
        statusBarView.autoresizingMask = [.width, .maxYMargin]
        contentView.addSubview(statusBarView)

        let editorY = statusBarHeight
        let editorHeight = bounds.height - tabBarHeight - statusBarHeight
        editorView = EditorView(frame: NSRect(
            x: 0, y: editorY,
            width: bounds.width, height: editorHeight
        ))
        editorView.autoresizingMask = [.width, .height]
        editorView.delegate = self
        editorCommands = EditorCommands(textView: editorView.textView)
        contentView.addSubview(editorView)

        documentManager.delegate = self
        documentManager.createNewDocument()
    }

    // MARK: - File Actions

    func saveCurrentDocument() {
        guard let doc = documentManager.activeDocument else { return }
        doc.content = editorView.text
        if doc.fileURL == nil { saveCurrentDocumentAs(); return }
        do {
            try doc.save()
            updateTabTitle(for: doc)
        } catch { NSAlert(error: error).runModal() }
    }

    func saveCurrentDocumentAs() {
        guard let doc = documentManager.activeDocument, let window = window else { return }
        doc.content = editorView.text
        let panel = NSSavePanel()
        panel.nameFieldStringValue = doc.title
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try doc.save(to: url)
                self?.window?.title = "NotepadNext — \(doc.title)"
                self?.updateTabTitle(for: doc)
            } catch { NSAlert(error: error).runModal() }
        }
    }

    func closeCurrentTab() {
        guard documentManager.activeIndex >= 0 else { return }
        _ = documentManager.closeDocument(at: documentManager.activeIndex)
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
        if let ts = editorView.textView.textStorage {
            ts.beginEditing(); ts.endEditing()
        }
        updateStatusBar(for: doc)
    }

    // MARK: - Zoom

    private var currentFontSize: CGFloat = 13

    func zoom(delta: Int) {
        currentFontSize = max(6, min(72, currentFontSize + CGFloat(delta)))
        editorView.textView.font = NSFont.monospacedSystemFont(ofSize: currentFontSize, weight: .regular)
    }

    func zoomReset() {
        currentFontSize = 13
        editorView.textView.font = NSFont.monospacedSystemFont(ofSize: currentFontSize, weight: .regular)
    }

    // MARK: - Word Wrap

    private var wordWrapEnabled = false

    func toggleWordWrap() {
        wordWrapEnabled.toggle()
        if wordWrapEnabled {
            editorView.textView.textContainer?.widthTracksTextView = true
            editorView.textView.isHorizontallyResizable = false
            if let sv = editorView.textView.enclosingScrollView {
                editorView.textView.textContainer?.containerSize = NSSize(width: sv.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            }
        } else {
            editorView.textView.textContainer?.widthTracksTextView = false
            editorView.textView.isHorizontallyResizable = true
            editorView.textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    // MARK: - Encoding

    func setEncodingLabel(_ id: String) {
        guard let doc = documentManager.activeDocument else { return }
        doc.encoding = encodingFromId(id)
        updateStatusBar(for: doc)
    }

    func convertEncoding(to id: String) {
        guard let doc = documentManager.activeDocument else { return }
        doc.encoding = encodingFromId(id)
        updateStatusBar(for: doc)
    }

    func setLineEnding(_ ending: String) {
        guard let doc = documentManager.activeDocument else { return }
        switch ending {
        case "LF": doc.lineEnding = .unix
        case "CRLF": doc.lineEnding = .windows
        case "CR": doc.lineEnding = .classic
        default: break
        }
        updateStatusBar(for: doc)
    }

    private func encodingFromId(_ id: String) -> String.Encoding {
        switch id {
        case "utf8", "utf8bom": return .utf8
        case "utf16le": return .utf16LittleEndian
        case "utf16be": return .utf16BigEndian
        case "ascii": return .ascii
        case "isoLatin1": return .isoLatin1
        case "windowsCP1252": return .windowsCP1252
        case "macOSRoman": return .macOSRoman
        default: return .utf8
        }
    }

    // MARK: - Helpers

    private func loadDocumentIntoEditor(_ doc: Document) {
        editorView.language = doc.language
        editorView.text = doc.content
        updateStatusBar(for: doc)
        window?.title = "NotepadNext — \(doc.fileURL?.path ?? doc.title)"
    }

    private func updateStatusBar(for doc: Document) {
        let text = editorView.text
        let lines = text.components(separatedBy: .newlines).count
        let selectedRange = editorView.textView.selectedRange()
        let upToCursor = (text as NSString).substring(to: selectedRange.location)
        let lineComponents = upToCursor.components(separatedBy: .newlines)
        let line = lineComponents.count
        let col = (lineComponents.last?.count ?? 0) + 1
        let enc: String = {
            switch doc.encoding {
            case .utf8: return "UTF-8"
            case .utf16: return "UTF-16"
            case .ascii: return "ASCII"
            default: return "ANSI"
            }
        }()
        statusBarView.update(line: line, column: col, length: text.count, lines: lines,
                             encoding: enc, lineEnding: doc.lineEnding.rawValue, language: doc.language)
    }

    private func updateTabTitle(for doc: Document) {
        guard let index = documentManager.documents.firstIndex(where: { $0.id == doc.id }) else { return }
        tabBarView.updateTab(at: index, title: doc.displayTitle, isModified: doc.isModified)
    }
}

// MARK: - DocumentManagerDelegate

extension MainWindowController: DocumentManagerDelegate {
    func documentManager(_ manager: DocumentManager, didAddDocument document: Document, at index: Int) {
        tabBarView.addTab(TabBarView.Tab(id: document.id, title: document.displayTitle, isModified: document.isModified))
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
        if let doc = documentManager.activeDocument { doc.content = editorView.text }
        documentManager.switchToDocument(at: index)
    }
    func tabBarView(_ tabBar: TabBarView, didCloseTabAt index: Int) {
        if let doc = documentManager.activeDocument { doc.content = editorView.text }
        _ = documentManager.closeDocument(at: index)
    }
    func tabBarViewDidRequestNewTab(_ tabBar: TabBarView) {
        if let doc = documentManager.activeDocument { doc.content = editorView.text }
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
