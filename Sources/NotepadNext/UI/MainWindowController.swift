import AppKit

class MainWindowController: NSWindowController {

    let documentManager = DocumentManager()
    private(set) var editorCommands: EditorCommands?

    private var tabBarView: TabBarView!
    private var editorView: EditorView!
    private var statusBarView: StatusBarView!
    private var folderPanel: FolderWorkspacePanel?
    private var documentMap: DocumentMapView?
    private var findReplaceController: FindReplaceWindowController?
    private var goToLineController: GoToLineWindowController?

    private let tabBarHeight: CGFloat = 30
    private let statusBarHeight: CGFloat = 22
    private var folderPanelWidth: CGFloat = 220
    private var documentMapWidth: CGFloat = 120

    func setupContent() {
        guard let contentView = window?.contentView else { return }

        let bounds = contentView.bounds

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

    private func relayoutPanels() {
        guard let contentView = window?.contentView else { return }
        let bounds = contentView.bounds
        let editorY = statusBarHeight
        let editorHeight = bounds.height - tabBarHeight - statusBarHeight

        var leftX: CGFloat = 0
        var rightInset: CGFloat = 0

        if let fp = folderPanel, !fp.isHidden {
            fp.frame = NSRect(x: 0, y: editorY, width: folderPanelWidth, height: editorHeight)
            leftX = folderPanelWidth
        }

        if let dm = documentMap, !dm.isHidden {
            dm.frame = NSRect(x: bounds.width - documentMapWidth, y: editorY,
                              width: documentMapWidth, height: editorHeight)
            rightInset = documentMapWidth
        }

        editorView.frame = NSRect(x: leftX, y: editorY,
                                   width: bounds.width - leftX - rightInset, height: editorHeight)
    }

    // MARK: - Panel Toggles

    func toggleFolderPanel() {
        guard let contentView = window?.contentView else { return }
        if folderPanel == nil {
            folderPanel = FolderWorkspacePanel(frame: .zero)
            folderPanel?.delegate = self
            folderPanel?.autoresizingMask = [.height, .maxXMargin]
            contentView.addSubview(folderPanel!)
        }
        folderPanel!.isHidden.toggle()
        relayoutPanels()
    }

    func openFolderInWorkspace() {
        guard let window = window else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            if self?.folderPanel == nil || self?.folderPanel?.isHidden == true {
                self?.toggleFolderPanel()
            }
            self?.folderPanel?.addFolder(url)
        }
    }

    func toggleDocumentMap() {
        guard let contentView = window?.contentView else { return }
        if documentMap == nil {
            documentMap = DocumentMapView(frame: .zero)
            documentMap?.autoresizingMask = [.height, .minXMargin]
            contentView.addSubview(documentMap!)
            documentMap?.attachToEditor(editorView.textView)
        }
        documentMap!.isHidden.toggle()
        relayoutPanels()
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

// MARK: - FolderWorkspaceDelegate

extension MainWindowController: FolderWorkspaceDelegate {
    func folderWorkspace(_ panel: FolderWorkspacePanel, didSelectFile url: URL) {
        documentManager.openDocument(at: url)
    }
}
