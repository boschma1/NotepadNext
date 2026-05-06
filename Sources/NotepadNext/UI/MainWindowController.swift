import AppKit

class MainWindowController: NSWindowController, NSTextViewDelegate {

    let documentManager = DocumentManager()
    private(set) var editorCommands: EditorCommands?

    private var tabBarView: TabBarView!
    var textView: NSTextView!
    private var editorScrollView: NSScrollView!
    private var lineNumberGutter: LineNumberGutter?
    private var statusBarView: StatusBarView!
    private var folderPanel: FolderWorkspacePanel?
    private var documentMap: DocumentMapView?
    private var docListPanel: DocumentListPanel?
    private var functionListPanel: FunctionListPanel?
    private var projectPanel: ProjectPanel?
    private var splitViewManager: SplitViewManager?
    private var findReplaceController: FindReplaceWindowController?
    private var findInFilesController: FindInFilesController?
    private var goToLineController: GoToLineWindowController?
    private var preferencesController: PreferencesWindowController?
    private var shortcutMapperController: ShortcutMapperController?
    private var pluginManagerController: PluginManagerController?
    private var udlEditorController: UDLEditorController?

    // Lightweight wrapper so the rest of the code can use editorView.text / .language
    var editorView: EditorViewAccessor!
    private var currentLineHighlighter: CurrentLineHighlighter?
    private var wordCompleter: WordCompleter?

    private let tabBarHeight: CGFloat = 30
    private let statusBarHeight: CGFloat = 22
    private var folderPanelWidth: CGFloat = 220
    private var documentMapWidth: CGFloat = 120

    func setupContent(createEmptyTab: Bool = true) {
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

        textView = PlainTextView(frame: editorScrollView.contentView.bounds)
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        let theme = ThemeManager.shared.currentTheme
        textView.font = theme.editorFont
        textView.textColor = theme.foreground
        textView.backgroundColor = theme.background
        textView.insertionPointColor = theme.caretColor
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = self

        editorScrollView.documentView = textView

        // Line number gutter (separate view, to the left of editor)
        let gw = LineNumberGutter.gutterWidth
        lineNumberGutter = LineNumberGutter(textView: textView, scrollView: editorScrollView)
        lineNumberGutter!.frame = NSRect(x: 0, y: ey, width: gw, height: eh)
        lineNumberGutter!.autoresizingMask = [.height, .maxXMargin]
        cv.addSubview(lineNumberGutter!)

        editorScrollView.frame = NSRect(x: gw, y: ey, width: b.width - gw, height: eh)

        cv.addSubview(editorScrollView)

        // Accessor for compatibility
        editorView = EditorViewAccessor(textView: textView)
        editorCommands = EditorCommands(textView: textView)
        wordCompleter = WordCompleter(textView: textView)
        splitViewManager = SplitViewManager(mainController: self)

        // Listen for theme changes
        ThemeManager.shared.onThemeChanged = { [weak self] theme in
            self?.applyEditorTheme(theme)
        }

        documentManager.delegate = self
        if createEmptyTab {
            documentManager.createNewDocument()
        }

        // Handle tab context menu "Copy Path"
        NotificationCenter.default.addObserver(forName: .init("CopyTabPath"), object: nil, queue: .main) { [weak self] n in
            guard let idx = n.object as? Int,
                  let doc = self?.documentManager.documents[safe: idx],
                  let path = doc.fileURL?.path else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path, forType: .string)
        }

        // Keep word wrap width in sync with window resize
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
            self?.windowDidResize()
        }
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard let doc = documentManager.activeDocument else { return }
        documentManager.updateContent(for: doc, content: textView.string)
        updateStatusBar(for: doc)
        scheduleHighlighting()
    }

    // MARK: - Syntax Highlighting (performance-optimized)

    private var highlightWorkItem: DispatchWorkItem?
    private let maxHighlightSize = 2_000_000  // Skip full highlighting for files > 2MB

    private func scheduleHighlighting() {
        highlightWorkItem?.cancel()

        // Small files: highlight immediately. Larger files: debounce.
        guard let ts = textView.textStorage else { return }
        if ts.length < 50_000 {
            applySyntaxHighlighting()
        } else {
            let item = DispatchWorkItem { [weak self] in
                self?.applySyntaxHighlighting()
            }
            highlightWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
        }
    }

    private func applySyntaxHighlighting() {
        guard let ts = textView.textStorage else { return }
        guard ts.length < maxHighlightSize else { return }

        let language = documentManager.activeDocument?.language ?? "Normal Text"
        let theme = ThemeManager.shared.currentTheme
        let rules = SyntaxRules.rules(for: language, theme: theme.syntax)
        guard !rules.isEmpty else { return }

        let fullRange: NSRange
        if ts.length > 100_000, let sv = textView.enclosingScrollView,
           let lm = textView.layoutManager, let tc = textView.textContainer {
            let visibleRect = sv.contentView.bounds
            let buffered = visibleRect.insetBy(dx: 0, dy: -visibleRect.height * 2)
            let glyphRange = lm.glyphRange(forBoundingRect: buffered, in: tc)
            fullRange = lm.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        } else {
            fullRange = NSRange(location: 0, length: ts.length)
        }

        let defaultFont = theme.editorFont

        ts.beginEditing()
        ts.addAttribute(.foregroundColor, value: theme.foreground, range: fullRange)
        ts.addAttribute(.font, value: defaultFont, range: fullRange)

        for rule in rules {
            guard let regex = rule.regex else { continue }
            regex.enumerateMatches(in: ts.string, range: fullRange) { match, _, _ in
                guard let mr = match?.range else { return }
                ts.addAttribute(.foregroundColor, value: rule.color, range: mr)
                if let trait = rule.fontTrait {
                    let styled = NSFontManager.shared.convert(defaultFont, toHaveTrait: trait)
                    ts.addAttribute(.font, value: styled, range: mr)
                }
            }
        }

        // Save wrap state before endEditing triggers relayout
        let wasWrapping = wordWrapEnabled
        ts.endEditing()

        // Restore wrap state if it was on (endEditing resets container)
        if wasWrapping {
            windowDidResize()
        }
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

    func toggleDocumentList() {
        guard let cv = window?.contentView else { return }
        if docListPanel == nil {
            docListPanel = DocumentListPanel(frame: .zero)
            docListPanel?.attach(to: documentManager)
            docListPanel?.delegate = self
            docListPanel?.autoresizingMask = [.height, .minXMargin]
            cv.addSubview(docListPanel!)
        }
        docListPanel?.reload()
        docListPanel!.isHidden.toggle()
        relayoutPanels()
    }

    func toggleFunctionList() {
        guard let cv = window?.contentView else { return }
        if functionListPanel == nil {
            functionListPanel = FunctionListPanel(frame: .zero)
            functionListPanel?.delegate = self
            functionListPanel?.autoresizingMask = [.height, .minXMargin]
            cv.addSubview(functionListPanel!)
        }
        let lang = documentManager.activeDocument?.language ?? "Normal Text"
        functionListPanel?.parse(text: textView.string, language: lang)
        functionListPanel!.isHidden.toggle()
        relayoutPanels()
    }

    func toggleProjectPanel() {
        guard let cv = window?.contentView else { return }
        if projectPanel == nil {
            projectPanel = ProjectPanel(frame: .zero)
            projectPanel?.delegate = self
            projectPanel?.autoresizingMask = [.height, .maxXMargin]
            cv.addSubview(projectPanel!)
        }
        projectPanel!.isHidden.toggle()
        relayoutPanels()
    }

    func toggleSplitView() {
        guard let cv = window?.contentView else { return }
        let b = cv.bounds
        let ey = statusBarHeight
        let eh = b.height - tabBarHeight - statusBarHeight
        let editorFrame = editorScrollView.frame

        splitViewManager?.toggle(in: cv, editorFrame: editorFrame)

        if let svm = splitViewManager, svm.isActive,
           let (mainF, secondF) = svm.splitFrames(for: editorFrame) {
            editorScrollView.frame = mainF
            svm.secondScrollView?.frame = secondF
        } else {
            relayoutPanels()
        }
    }

    func rotateSplitView() {
        splitViewManager?.toggleOrientation()
        if let svm = splitViewManager, svm.isActive {
            let editorFrame = NSRect(x: editorScrollView.frame.minX, y: editorScrollView.frame.minY,
                                      width: editorScrollView.frame.width + (svm.secondScrollView?.frame.width ?? 0) + 2,
                                      height: max(editorScrollView.frame.height, svm.secondScrollView?.frame.height ?? 0))
            if let (mainF, secondF) = svm.splitFrames(for: editorFrame) {
                editorScrollView.frame = mainF
                svm.secondScrollView?.frame = secondF
            }
        }
    }

    private func relayoutPanels() {
        guard let cv = window?.contentView else { return }
        let b = cv.bounds
        let ey = statusBarHeight
        let eh = b.height - tabBarHeight - statusBarHeight
        var leftX: CGFloat = LineNumberGutter.gutterWidth
        var rightInset: CGFloat = 0

        // Left panels
        var leftPanelWidth: CGFloat = 0
        if let fp = folderPanel, !fp.isHidden {
            fp.frame = NSRect(x: 0, y: ey, width: folderPanelWidth, height: eh)
            leftPanelWidth = folderPanelWidth
        }
        if let pp = projectPanel, !pp.isHidden {
            let ppWidth: CGFloat = 200
            pp.frame = NSRect(x: leftPanelWidth, y: ey, width: ppWidth, height: eh)
            leftPanelWidth += ppWidth
        }
        if leftPanelWidth > 0 {
            leftX = leftPanelWidth + LineNumberGutter.gutterWidth
            lineNumberGutter?.frame = NSRect(x: leftPanelWidth, y: ey, width: LineNumberGutter.gutterWidth, height: eh)
        } else {
            lineNumberGutter?.frame = NSRect(x: 0, y: ey, width: LineNumberGutter.gutterWidth, height: eh)
        }
        if let dm = documentMap, !dm.isHidden {
            dm.frame = NSRect(x: b.width - documentMapWidth - rightInset, y: ey, width: documentMapWidth, height: eh)
            rightInset += documentMapWidth
        }
        let funcListWidth: CGFloat = 200
        if let fl = functionListPanel, !fl.isHidden {
            fl.frame = NSRect(x: b.width - funcListWidth - rightInset, y: ey, width: funcListWidth, height: eh)
            rightInset += funcListWidth
        }
        let docListWidth: CGFloat = 250
        if let dl = docListPanel, !dl.isHidden {
            dl.frame = NSRect(x: b.width - docListWidth - rightInset, y: ey, width: docListWidth, height: eh)
            rightInset += docListWidth
        }
        editorScrollView.frame = NSRect(x: leftX, y: ey, width: b.width - leftX - rightInset, height: eh)
    }

    // MARK: - Theme

    private func applyEditorTheme(_ theme: EditorTheme) {
        textView.font = theme.editorFont
        textView.textColor = theme.foreground
        textView.backgroundColor = theme.background
        textView.insertionPointColor = theme.caretColor
        textView.selectedTextAttributes = [.backgroundColor: theme.selectionBg]
        currentFontSize = theme.editorFont.pointSize
        lineNumberGutter?.needsDisplay = true
        applySyntaxHighlighting()
    }

    // MARK: - File Actions

    func saveCurrentDocument() {
        guard let doc = documentManager.activeDocument else { return }
        doc.content = textView.string
        guard let _ = doc.fileURL else { saveCurrentDocumentAs(); return }
        do { try doc.save(); updateTabTitle(for: doc) }
        catch { saveCurrentDocumentAs() }
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

    func showFindInFiles() {
        if findInFilesController == nil {
            findInFilesController = FindInFilesController()
            findInFilesController?.openFileDelegate = self
        }
        let dir = documentManager.activeDocument?.fileURL?.deletingLastPathComponent().path
        findInFilesController?.showAndFocus(directory: dir)
    }

    func showPreferences() {
        if preferencesController == nil {
            preferencesController = PreferencesWindowController()
        }
        preferencesController?.showAndFocus()
    }

    func showShortcutMapper() {
        if shortcutMapperController == nil {
            shortcutMapperController = ShortcutMapperController()
        }
        shortcutMapperController?.showAndFocus()
    }

    func showPluginManager() {
        if pluginManagerController == nil {
            pluginManagerController = PluginManagerController()
        }
        pluginManagerController?.showAndFocus()
    }

    func showUDLEditor() {
        if udlEditorController == nil {
            udlEditorController = UDLEditorController()
        }
        udlEditorController?.showAndFocus()
    }

    func runInTerminal() {
        guard let url = documentManager.activeDocument?.fileURL else {
            NSSound.beep(); return
        }
        let dir = url.deletingLastPathComponent().path
        let script = "tell application \"Terminal\" to do script \"cd \\\"\(dir)\\\"\""
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    func openInDefaultApp() {
        guard let url = documentManager.activeDocument?.fileURL else { return }
        NSWorkspace.shared.open(url)
    }

    func revealInFinder() {
        guard let url = documentManager.activeDocument?.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func setLanguage(_ language: String) {
        guard let doc = documentManager.activeDocument else { return }
        doc.language = language
        editorView.language = language
        updateStatusBar(for: doc)
    }

    func triggerAutoComplete() {
        wordCompleter?.complete()
    }

    func showHashTools() {
        let sel = textView.selectedRange()
        var selected: String? = nil
        if sel.length > 0 {
            selected = (textView.string as NSString).substring(with: sel)
        }
        HashTools.showHashDialog(selectedText: selected)
    }

    // MARK: - Zoom

    private var currentFontSize: CGFloat = ThemeManager.shared.currentTheme.editorFont.pointSize

    func zoom(delta: Int) {
        currentFontSize = max(6, min(72, currentFontSize + CGFloat(delta)))
        let currentFont = ThemeManager.shared.currentTheme.editorFont
        let newFont = NSFontManager.shared.convert(currentFont, toSize: currentFontSize)
        textView.font = newFont
        ThemeManager.shared.currentTheme.editorFont = newFont
        lineNumberGutter?.needsDisplay = true
    }

    func zoomReset() {
        currentFontSize = 13
        let currentFont = ThemeManager.shared.currentTheme.editorFont
        let newFont = NSFontManager.shared.convert(currentFont, toSize: currentFontSize)
        textView.font = newFont
        ThemeManager.shared.currentTheme.editorFont = newFont
        lineNumberGutter?.needsDisplay = true
    }

    // MARK: - Word Wrap

    private var wordWrapEnabled = false

    func toggleWordWrap() {
        wordWrapEnabled.toggle()
        // Save per-tab
        documentManager.activeDocument?.wordWrapEnabled = wordWrapEnabled
        applyWordWrap()
    }

    private func applyWordWrap() {
        guard let container = textView.textContainer,
              let sv = textView.enclosingScrollView else { return }

        if wordWrapEnabled {
            container.widthTracksTextView = false
            textView.isHorizontallyResizable = false
            let w = sv.contentSize.width - container.lineFragmentPadding * 2
            container.containerSize = NSSize(width: w, height: CGFloat.greatestFiniteMagnitude)
            textView.maxSize = NSSize(width: w, height: CGFloat.greatestFiniteMagnitude)
            textView.frame.size.width = sv.contentSize.width
            sv.hasHorizontalScroller = false
        } else {
            container.widthTracksTextView = false
            textView.isHorizontallyResizable = true
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            sv.hasHorizontalScroller = true
        }
    }

    /// Called when window resizes to keep wrap width in sync
    func windowDidResize() {
        guard wordWrapEnabled else { return }
        applyWordWrap()
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
        if doc.content.count < maxHighlightSize {
            applySyntaxHighlighting()
        }
        // Restore per-tab word wrap
        if doc.wordWrapEnabled != wordWrapEnabled {
            wordWrapEnabled = doc.wordWrapEnabled
            applyWordWrap()
        }
        updateStatusBar(for: doc)
        window?.title = "NotepadNext — \(doc.fileURL?.path ?? doc.title)"
    }

    private func updateStatusBar(for doc: Document) {
        let text = textView.string
        let lines = text.components(separatedBy: .newlines).count
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        let sel = textView.selectedRange()
        let upTo = (text as NSString).substring(to: sel.location)
        let lc = upTo.components(separatedBy: .newlines)
        let enc: String = { switch doc.encoding {
        case .utf8: return "UTF-8"; case .utf16: return "UTF-16"
        case .ascii: return "ASCII"; default: return "ANSI" } }()

        // Detect indentation from content
        let indent = detectIndentation(text)
        doc.usesSpaces = indent.usesSpaces
        doc.tabSize = indent.size
        let indentStr = indent.usesSpaces ? "Spaces: \(indent.size)" : "Tabs"

        statusBarView.update(line: lc.count, column: (lc.last?.count ?? 0) + 1,
                             length: text.count, lines: lines, words: words,
                             encoding: enc, lineEnding: doc.lineEnding.rawValue, language: doc.language,
                             indentation: indentStr)
    }

    private func detectIndentation(_ text: String) -> (usesSpaces: Bool, size: Int) {
        var spaceLines = 0
        var tabLines = 0
        var commonSpaces = 0
        let lines = text.components(separatedBy: .newlines).prefix(100) // Sample first 100 lines

        for line in lines {
            if line.hasPrefix("\t") { tabLines += 1 }
            else if line.hasPrefix("  ") {
                spaceLines += 1
                let count = line.prefix(while: { $0 == " " }).count
                if commonSpaces == 0 { commonSpaces = count }
                else { commonSpaces = min(commonSpaces, count) }
            }
        }

        if tabLines > spaceLines { return (false, 4) }
        if commonSpaces > 0 { return (true, min(commonSpaces, 8)) }
        return (false, 4)
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

    func tabBarView(_ tabBar: TabBarView, didDragOutTabAt index: Int) {
        moveTabToNewInstance(at: index)
    }

    private func moveTabToNewInstance(at index: Int) {
        guard let doc = documentManager.documents[safe: index] else { return }

        // Sync content if it's the active document
        if index == documentManager.activeIndex {
            doc.content = textView.string
        }

        // Save content to a temp file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile: URL

        if let fileURL = doc.fileURL {
            tempFile = fileURL
        } else {
            let name = doc.title.replacingOccurrences(of: " ", with: "_") + ".txt"
            tempFile = tempDir.appendingPathComponent(name)
            try? doc.content.write(to: tempFile, atomically: true, encoding: .utf8)
        }

        // Launch a new instance with the file
        let appPath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments[0]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: appPath)
        let winFrame = window?.frame ?? .zero
        let offsetX = Int(winFrame.origin.x + 100)
        let offsetY = Int(winFrame.origin.y - 100)
        process.arguments = ["--new-instance", "--title", doc.title,
                             "--origin", "\(offsetX),\(offsetY)", tempFile.path]
        try? process.run()

        // Force-close the tab without save prompt
        doc.isModified = false
        _ = documentManager.closeDocument(at: index)
    }
}

// MARK: - FolderWorkspaceDelegate

extension MainWindowController: FolderWorkspaceDelegate {
    func folderWorkspace(_ panel: FolderWorkspacePanel, didSelectFile url: URL) {
        documentManager.openDocument(at: url)
    }
}

// MARK: - FindInFilesDelegate

extension MainWindowController: FindInFilesDelegate {
    func findInFiles(_ controller: FindInFilesController, openFile path: String, atLine line: Int) {
        let url = URL(fileURLWithPath: path)
        documentManager.openDocument(at: url)
        // Jump to line
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let tv = self?.textView else { return }
            let content = tv.string as NSString
            var currentLine = 1
            var targetLocation = 0
            content.enumerateSubstrings(in: NSRange(location: 0, length: content.length),
                                        options: [.byLines, .substringNotRequired]) { _, range, _, stop in
                if currentLine == line { targetLocation = range.location; stop.pointee = true }
                currentLine += 1
            }
            tv.setSelectedRange(NSRange(location: targetLocation, length: 0))
            tv.scrollRangeToVisible(NSRange(location: targetLocation, length: 0))
        }
    }
}

// MARK: - DocumentListDelegate

extension MainWindowController: DocumentListDelegate {
    func documentList(_ panel: DocumentListPanel, didSelectDocumentAt index: Int) {
        documentManager.activeDocument?.content = textView.string
        documentManager.switchToDocument(at: index)
    }
}

// MARK: - FunctionListDelegate

extension MainWindowController: FunctionListDelegate {
    func functionList(_ panel: FunctionListPanel, didSelectFunction lineNumber: Int) {
        let content = textView.string as NSString
        var currentLine = 1
        var targetLocation = 0
        content.enumerateSubstrings(in: NSRange(location: 0, length: content.length),
                                    options: [.byLines, .substringNotRequired]) { _, range, _, stop in
            if currentLine == lineNumber { targetLocation = range.location; stop.pointee = true }
            currentLine += 1
        }
        textView.setSelectedRange(NSRange(location: targetLocation, length: 0))
        textView.scrollRangeToVisible(NSRange(location: targetLocation, length: 0))
    }
}

// MARK: - ProjectPanelDelegate

extension MainWindowController: ProjectPanelDelegate {
    func projectPanel(_ panel: ProjectPanel, didSelectFile url: URL) {
        documentManager.openDocument(at: url)
    }
}
