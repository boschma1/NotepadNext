import AppKit

class MainWindowController: NSWindowController, NSTextViewDelegate {

    let documentManager = DocumentManager()
    private(set) var editorCommands: EditorCommands?

    private var tabBarView: TabBarView!
    var textView: NSTextView!
    private var editorScrollView: NSScrollView!
    private var statusBarView: StatusBarView!
    private var folderPanel: FolderWorkspacePanel?
    private var documentMap: DocumentMapView?
    private var findReplaceController: FindReplaceWindowController?
    private var goToLineController: GoToLineWindowController?

    // Lightweight wrapper so the rest of the code can use editorView.text / .language
    var editorView: EditorViewAccessor!

    private let tabBarHeight: CGFloat = 30
    private let statusBarHeight: CGFloat = 22
    private var folderPanelWidth: CGFloat = 220
    private var documentMapWidth: CGFloat = 120

    func setupContent() {
        guard let cv = window?.contentView else { return }
        let b = cv.bounds

        // Tab bar
        tabBarView = TabBarView(frame: NSRect(x: 0, y: b.height - tabBarHeight, width: b.width, height: tabBarHeight))
        tabBarView.autoresizingMask = [.width, .minYMargin]
        tabBarView.delegate = self
        cv.addSubview(tabBarView)

        // Status bar
        statusBarView = StatusBarView(frame: NSRect(x: 0, y: 0, width: b.width, height: statusBarHeight))
        statusBarView.autoresizingMask = [.width, .maxYMargin]
        cv.addSubview(statusBarView)

        // Editor — built directly, matching the working test
        let ey = statusBarHeight
        let eh = b.height - tabBarHeight - statusBarHeight
        editorScrollView = NSScrollView(frame: NSRect(x: 0, y: ey, width: b.width, height: eh))
        editorScrollView.autoresizingMask = [.width, .height]
        editorScrollView.hasVerticalScroller = true
        editorScrollView.hasHorizontalScroller = true

        textView = NSTextView(frame: editorScrollView.contentView.bounds)
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .textColor
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = self

        editorScrollView.documentView = textView
        cv.addSubview(editorScrollView)

        // Accessor for compatibility
        editorView = EditorViewAccessor(textView: textView)
        editorCommands = EditorCommands(textView: textView)

        documentManager.delegate = self
        documentManager.createNewDocument()
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard let doc = documentManager.activeDocument else { return }
        documentManager.updateContent(for: doc, content: textView.string)
        updateStatusBar(for: doc)
    }

    // MARK: - Panel Toggles

    func toggleFolderPanel() {
        guard let cv = window?.contentView else { return }
        if folderPanel == nil {
            folderPanel = FolderWorkspacePanel(frame: .zero)
            folderPanel?.delegate = self
            folderPanel?.autoresizingMask = [.height, .maxXMargin]
            cv.addSubview(folderPanel!)
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
        guard let cv = window?.contentView else { return }
        if documentMap == nil {
            documentMap = DocumentMapView(frame: .zero)
            documentMap?.autoresizingMask = [.height, .minXMargin]
            cv.addSubview(documentMap!)
            documentMap?.attachToEditor(textView)
        }
        documentMap!.isHidden.toggle()
        relayoutPanels()
    }

    private func relayoutPanels() {
        guard let cv = window?.contentView else { return }
        let b = cv.bounds
        let ey = statusBarHeight
        let eh = b.height - tabBarHeight - statusBarHeight
        var leftX: CGFloat = 0
        var rightInset: CGFloat = 0
        if let fp = folderPanel, !fp.isHidden {
            fp.frame = NSRect(x: 0, y: ey, width: folderPanelWidth, height: eh)
            leftX = folderPanelWidth
        }
        if let dm = documentMap, !dm.isHidden {
            dm.frame = NSRect(x: b.width - documentMapWidth, y: ey, width: documentMapWidth, height: eh)
            rightInset = documentMapWidth
        }
        editorScrollView.frame = NSRect(x: leftX, y: ey, width: b.width - leftX - rightInset, height: eh)
    }

    // MARK: - File Actions

    func saveCurrentDocument() {
        guard let doc = documentManager.activeDocument else { return }
        doc.content = textView.string
        if doc.fileURL == nil { saveCurrentDocumentAs(); return }
        do { try doc.save(); updateTabTitle(for: doc) }
        catch { NSAlert(error: error).runModal() }
    }

    func saveCurrentDocumentAs() {
        guard let doc = documentManager.activeDocument, let window = window else { return }
        doc.content = textView.string
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
            findReplaceController = FindReplaceWindowController(textView: textView)
        }
        findReplaceController?.showAndFocus()
    }

    func showGoToLine() {
        if goToLineController == nil {
            goToLineController = GoToLineWindowController(textView: textView)
        }
        goToLineController?.showAndFocus()
    }

    func setLanguage(_ language: String) {
        guard let doc = documentManager.activeDocument else { return }
        doc.language = language
        editorView.language = language
        updateStatusBar(for: doc)
    }

    // MARK: - Zoom

    private var currentFontSize: CGFloat = 13

    func zoom(delta: Int) {
        currentFontSize = max(6, min(72, currentFontSize + CGFloat(delta)))
        textView.font = NSFont.monospacedSystemFont(ofSize: currentFontSize, weight: .regular)
    }

    func zoomReset() {
        currentFontSize = 13
        textView.font = NSFont.monospacedSystemFont(ofSize: currentFontSize, weight: .regular)
    }

    // MARK: - Word Wrap

    private var wordWrapEnabled = false

    func toggleWordWrap() {
        wordWrapEnabled.toggle()
        if wordWrapEnabled {
            textView.textContainer?.widthTracksTextView = true
            textView.isHorizontallyResizable = false
            if let sv = textView.enclosingScrollView {
                textView.textContainer?.containerSize = NSSize(width: sv.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            }
        } else {
            textView.textContainer?.widthTracksTextView = false
            textView.isHorizontallyResizable = true
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    // MARK: - Encoding

    func setEncodingLabel(_ id: String) {
        guard let doc = documentManager.activeDocument else { return }
        doc.encoding = encodingFromId(id); updateStatusBar(for: doc)
    }
    func convertEncoding(to id: String) {
        guard let doc = documentManager.activeDocument else { return }
        doc.encoding = encodingFromId(id); updateStatusBar(for: doc)
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
        textView.string = doc.content
        updateStatusBar(for: doc)
        window?.title = "NotepadNext — \(doc.fileURL?.path ?? doc.title)"
    }

    private func updateStatusBar(for doc: Document) {
        let text = textView.string
        let lines = text.components(separatedBy: .newlines).count
        let sel = textView.selectedRange()
        let upTo = (text as NSString).substring(to: sel.location)
        let lc = upTo.components(separatedBy: .newlines)
        let enc: String = { switch doc.encoding {
        case .utf8: return "UTF-8"; case .utf16: return "UTF-16"
        case .ascii: return "ASCII"; default: return "ANSI" } }()
        statusBarView.update(line: lc.count, column: (lc.last?.count ?? 0) + 1,
                             length: text.count, lines: lines,
                             encoding: enc, lineEnding: doc.lineEnding.rawValue, language: doc.language)
    }

    private func updateTabTitle(for doc: Document) {
        guard let i = documentManager.documents.firstIndex(where: { $0.id == doc.id }) else { return }
        tabBarView.updateTab(at: i, title: doc.displayTitle, isModified: doc.isModified)
    }
}

// MARK: - EditorViewAccessor (compatibility shim)

class EditorViewAccessor {
    let textView: NSTextView
    var language: String = "Normal Text"
    var text: String {
        get { textView.string }
        set { textView.string = newValue }
    }
    init(textView: NSTextView) { self.textView = textView }
}

// MARK: - DocumentManagerDelegate

extension MainWindowController: DocumentManagerDelegate {
    func documentManager(_ m: DocumentManager, didAddDocument doc: Document, at i: Int) {
        tabBarView.addTab(TabBarView.Tab(id: doc.id, title: doc.displayTitle, isModified: doc.isModified))
    }
    func documentManager(_ m: DocumentManager, didRemoveDocumentAt i: Int) { tabBarView.removeTab(at: i) }
    func documentManager(_ m: DocumentManager, didSwitchToDocument doc: Document, at i: Int) {
        tabBarView.selectTab(at: i); loadDocumentIntoEditor(doc)
    }
    func documentManager(_ m: DocumentManager, didUpdateDocument doc: Document, at i: Int) {
        tabBarView.updateTab(at: i, title: doc.displayTitle, isModified: doc.isModified)
    }
}

// MARK: - TabBarViewDelegate

extension MainWindowController: TabBarViewDelegate {
    func tabBarView(_ t: TabBarView, didSelectTabAt i: Int) {
        documentManager.activeDocument?.content = textView.string
        documentManager.switchToDocument(at: i)
    }
    func tabBarView(_ t: TabBarView, didCloseTabAt i: Int) {
        documentManager.activeDocument?.content = textView.string
        _ = documentManager.closeDocument(at: i)
    }
    func tabBarViewDidRequestNewTab(_ t: TabBarView) {
        documentManager.activeDocument?.content = textView.string
        documentManager.createNewDocument()
    }
}

// MARK: - FolderWorkspaceDelegate

extension MainWindowController: FolderWorkspaceDelegate {
    func folderWorkspace(_ panel: FolderWorkspacePanel, didSelectFile url: URL) {
        documentManager.openDocument(at: url)
    }
}
