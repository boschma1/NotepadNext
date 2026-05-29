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
    private(set) var invisiblesLayoutManager: InvisiblesLayoutManager?

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

        installInvisiblesLayoutManager()

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

        // Apply the saved window appearance (standard / transparency).
        applyAppearanceStyle(EditorSettings.appearanceStyle)

        // Re-apply appearance when the user changes transparency level in
        // Preferences.
        NotificationCenter.default.addObserver(forName: .nmmAppearanceDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.reapplyCurrentAppearanceStyle()
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

        // Re-check pending external file changes when the window comes
        // back to the foreground (e.g. user finished editing in TextEdit
        // and switched back to NotepadMacMac).
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
            self?.processPendingExternalChanges()
        }
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard let doc = documentManager.activeDocument else { return }
        documentManager.updateContent(for: doc, content: textView.string)
        updateStatusBar(for: doc)
        scheduleHighlighting()
    }

    /// Intercept Enter to expand `=rand(p)` / `=rand(p, s)` into Lorem Ipsum
    /// filler text, Microsoft-Word style.
    func textView(_ tv: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:))
            && expandRandIfPresent(in: tv) {
            return true
        }
        return false
    }

    /// If the line at the caret is `=rand(p)` / `=rand(p, s)`, replace it
    /// with the corresponding Lorem Ipsum text and return true.
    @discardableResult
    private func expandRandIfPresent(in tv: NSTextView) -> Bool {
        let nsText = tv.string as NSString
        let caret = tv.selectedRange().location
        guard caret <= nsText.length else { return false }

        // Range of the current line, stripped of any trailing newline.
        let fullLineRange = nsText.lineRange(for: NSRange(location: caret, length: 0))
        var lineEnd = NSMaxRange(fullLineRange)
        if lineEnd > fullLineRange.location,
           nsText.character(at: lineEnd - 1) == 0x0A {
            lineEnd -= 1
        }
        let lineRange = NSRange(location: fullLineRange.location,
                                length: lineEnd - fullLineRange.location)
        let line = nsText.substring(with: lineRange)

        let pattern = #"^\s*=rand\((\d+)(?:\s*,\s*(\d+))?\)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        let lineNS = line as NSString
        guard let match = regex.firstMatch(in: line,
                                            range: NSRange(location: 0, length: lineNS.length)) else {
            return false
        }

        let paragraphs = Int(lineNS.substring(with: match.range(at: 1))) ?? 0
        let sentencesRange = match.range(at: 2)
        let sentences = sentencesRange.location == NSNotFound
            ? 3
            : (Int(lineNS.substring(with: sentencesRange)) ?? 3)
        guard paragraphs > 0, sentences > 0 else { return false }

        let replacement = LoremIpsum.generate(paragraphs: paragraphs, sentences: sentences)
        guard tv.shouldChangeText(in: lineRange, replacementString: replacement) else {
            return false
        }
        tv.textStorage?.replaceCharacters(in: lineRange, with: replacement)
        tv.didChangeText()
        // Place caret at the end of the inserted text.
        let newCaret = lineRange.location + (replacement as NSString).length
        tv.setSelectedRange(NSRange(location: newCaret, length: 0))
        return true
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
            // Inherit the current word-wrap setting in the new pane.
            if let secondTV = svm.secondTextView {
                applyWordWrap(to: secondTV, wrap: wordWrapEnabled)
            }
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

        // If split view is active, divide the editor area between the two
        // panes so they grow equally when the window or side-panel layout
        // changes.
        if let svm = splitViewManager, svm.isActive,
           let (mainF, secondF) = svm.splitFrames(for: editorScrollView.frame) {
            editorScrollView.frame = mainF
            svm.secondScrollView?.frame = secondF
        }
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
        // Theme change overwrites textView.backgroundColor; re-apply
        // the current translucency level so transparency persists.
        reapplyCurrentAppearanceStyle()
    }

    // MARK: - File Actions

    func saveCurrentDocument() {
        guard let doc = documentManager.activeDocument else { return }
        doc.content = textView.string
        guard let _ = doc.fileURL else { saveCurrentDocumentAs(); return }
        do { try documentManager.saveDocument(doc); updateTabTitle(for: doc) }
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
                try self?.documentManager.saveDocument(doc, to: url)
                self?.window?.title = "NotepadMacMac — \(doc.title)"
                self?.updateTabTitle(for: doc)
            } catch { NSAlert(error: error).runModal() }
        }
    }

    // MARK: - External file change handling

    /// IDs of documents that have a pending external-change event we
    /// haven't yet shown the user. We re-derive `wasDeleted` from a
    /// fresh stat at drain time so multiple watcher events for the
    /// same underlying save coalesce into at most one prompt.
    private var externalChangeQueue: Set<UUID> = []
    private var isPromptingExternalChange = false

    /// Show the queued external-change prompt for the currently-active
    /// document, if any. Other docs' prompts wait until the user
    /// switches to them.
    fileprivate func processPendingExternalChanges() {
        guard !isPromptingExternalChange,
              let window = window, window.isKeyWindow,
              let doc = documentManager.activeDocument,
              externalChangeQueue.remove(doc.id) != nil,
              let url = doc.fileURL
        else { return }

        // Fresh-check the disk state. The queue may have been
        // populated by multiple watcher events for the same external
        // save (atomic rename + post-rename mtime/xattr touches), or
        // the user may have already reloaded in response to an
        // earlier dialog. In either case, if the doc's authoritative
        // state already matches the disk, drop the prompt.
        let currentSig = Document.diskSignature(of: url)
        if currentSig == nil {
            guard doc.lastKnownDiskSignature != nil else { return }
            promptExternalChange(for: doc, wasDeleted: true)
        } else {
            guard currentSig != doc.lastKnownDiskSignature else { return }
            promptExternalChange(for: doc, wasDeleted: false)
        }
    }

    private func promptExternalChange(for doc: Document, wasDeleted: Bool) {
        guard let window = window else { return }
        // Make sure the doc's in-memory content reflects the editor in
        // case the user just typed something — important for the
        // "unsaved changes" framing.
        if doc.id == documentManager.activeDocument?.id {
            doc.content = textView.string
        }

        let alert = NSAlert()
        let name = doc.fileURL?.lastPathComponent ?? doc.title

        if wasDeleted {
            alert.messageText = "\"\(name)\" has been deleted on disk."
            alert.informativeText = "The file was removed or moved by another application. The content remains here as an unsaved buffer — save it to restore the file."
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .warning
            doc.isModified = true
            if let idx = documentManager.documents.firstIndex(where: { $0.id == doc.id }) {
                documentManager.delegate?.documentManager(documentManager, didUpdateDocument: doc, at: idx)
            }
            isPromptingExternalChange = true
            alert.beginSheetModal(for: window) { [weak self, weak doc] _ in
                guard let self else { return }
                self.isPromptingExternalChange = false
                // Acknowledge the deletion so a subsequent watcher
                // event with the same nil signature doesn't re-prompt.
                doc?.lastKnownDiskSignature = nil
                self.processPendingExternalChanges()
            }
            return
        }

        alert.messageText = "\"\(name)\" has changed on disk."
        if doc.isModified {
            alert.informativeText = "Another application modified this file, but you have unsaved changes in NotepadMacMac. Reloading will discard your unsaved changes."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Keep My Version")   // default
            alert.addButton(withTitle: "Reload From Disk")
        } else {
            alert.informativeText = "Another application modified this file. Reload it from disk to see the latest content?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Reload From Disk")  // default
            alert.addButton(withTitle: "Keep My Version")
        }

        let reloadIsDefault = !doc.isModified
        isPromptingExternalChange = true
        alert.beginSheetModal(for: window) { [weak self, weak doc] response in
            guard let self else { return }
            self.isPromptingExternalChange = false
            defer { self.processPendingExternalChanges() }
            guard let doc else { return }

            let userChoseReload = (response == .alertFirstButtonReturn) == reloadIsDefault
            if userChoseReload {
                self.reloadDocumentFromDisk(doc)
            } else {
                // "Keep my version" — record the current on-disk
                // signature as the authoritative one so we don't
                // immediately re-prompt about the same external
                // state. A *subsequent* external change will still
                // differ and re-prompt.
                if let url = doc.fileURL {
                    doc.lastKnownDiskSignature = Document.diskSignature(of: url)
                }
            }
        }
    }

    private func reloadDocumentFromDisk(_ doc: Document) {
        do {
            try doc.load()
        } catch {
            NSAlert(error: error).runModal()
            return
        }

        // If the reloaded doc is the active one, refresh the editor
        // while preserving the caret position (clamped to the new
        // content length).
        if doc.id == documentManager.activeDocument?.id {
            let oldRange = textView.selectedRange()
            let oldScrollOrigin = editorScrollView?.contentView.bounds.origin
            loadDocumentIntoEditor(doc)
            let clampedLocation = min(oldRange.location, (doc.content as NSString).length)
            textView.setSelectedRange(NSRange(location: clampedLocation, length: 0))
            if let origin = oldScrollOrigin {
                textView.scroll(origin)
            }
        }
        if let idx = documentManager.documents.firstIndex(where: { $0.id == doc.id }) {
            documentManager.delegate?.documentManager(documentManager, didUpdateDocument: doc, at: idx)
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
        applyWordWrap(to: textView, wrap: wordWrapEnabled)
        // Apply the same setting to the second pane in split view.
        if let secondTV = splitViewManager?.secondTextView {
            applyWordWrap(to: secondTV, wrap: wordWrapEnabled)
        }
        // Force the layout manager to re-flow with the new container width
        // and tell the line-number gutter to redraw — otherwise it keeps
        // using the previous (pre-wrap) line-fragment positions.
        if let lm = textView.layoutManager, let tc = textView.textContainer,
           let ts = textView.textStorage {
            lm.invalidateLayout(forCharacterRange: NSRange(location: 0, length: ts.length),
                                actualCharacterRange: nil)
            lm.ensureLayout(for: tc)
        }
        lineNumberGutter?.needsDisplay = true
    }

    private func applyWordWrap(to tv: NSTextView, wrap: Bool) {
        guard let container = tv.textContainer,
              let sv = tv.enclosingScrollView else { return }

        if wrap {
            container.widthTracksTextView = false
            tv.isHorizontallyResizable = false
            let w = sv.contentSize.width - container.lineFragmentPadding * 2
            container.containerSize = NSSize(width: w, height: CGFloat.greatestFiniteMagnitude)
            tv.maxSize = NSSize(width: w, height: CGFloat.greatestFiniteMagnitude)
            tv.frame.size.width = sv.contentSize.width
            sv.hasHorizontalScroller = false
        } else {
            container.widthTracksTextView = false
            tv.isHorizontallyResizable = true
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            sv.hasHorizontalScroller = true
        }
    }

    /// Called when window resizes to keep panel layout, split view and word
    /// wrap in sync with the new window size.
    func windowDidResize() {
        relayoutPanels()
        if wordWrapEnabled {
            applyWordWrap()
        }
    }

    // MARK: - Formatting marks (invisibles)

    /// Swap the text view's default NSLayoutManager for our custom
    /// `InvisiblesLayoutManager`, preserving the existing text storage and
    /// text container. Done in-place so NSTextView keeps the wiring it
    /// configured in its own `init(frame:)`.
    private func installInvisiblesLayoutManager() {
        guard let storage = textView.textStorage,
              let oldLM = textView.layoutManager,
              let container = textView.textContainer
        else { return }

        let invisLM = InvisiblesLayoutManager()
        oldLM.removeTextContainer(at: 0)
        storage.removeLayoutManager(oldLM)
        storage.addLayoutManager(invisLM)
        invisLM.addTextContainer(container)
        invisLM.showsFormattingMarks = EditorSettings.showFormattingMarks
        invisiblesLayoutManager = invisLM
    }

    func toggleFormattingMarks() {
        let newValue = !EditorSettings.showFormattingMarks
        EditorSettings.showFormattingMarks = newValue
        invisiblesLayoutManager?.showsFormattingMarks = newValue
        textView.needsDisplay = true
    }

    var showFormattingMarks: Bool {
        EditorSettings.showFormattingMarks
    }

    // MARK: - Window appearance (standard / transparency)

    /// Apply the chosen window-chrome style. Safe to call repeatedly.
    private func applyAppearanceStyle(_ style: AppearanceStyle) {
        guard let window = window else { return }

        let theme = ThemeManager.shared.currentTheme

        switch style {
        case .standard:
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            window.titlebarAppearsTransparent = false
            window.titleVisibility = .visible
            editorScrollView?.drawsBackground = true
            editorScrollView?.contentView.drawsBackground = true
            textView?.drawsBackground = true
            textView?.backgroundColor = theme.background
            tabBarView?.backgroundAlpha = 1.0
            lineNumberGutter?.backgroundAlpha = 1.0

        case .transparency:
            // Subtle Terminal-style translucency: editor + chrome + title bar
            // all tinted with the theme background at the user-chosen opacity.
            let alpha = EditorSettings.transparencyAlpha
            let tint = theme.background.withAlphaComponent(alpha)
            window.isOpaque = false
            // Paint the entire window chrome (incl. the transparent title bar
            // area) with the same translucent theme colour.
            window.backgroundColor = tint
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .visible
            editorScrollView?.drawsBackground = false
            editorScrollView?.contentView.drawsBackground = false
            // Let the window's tinted background show through the editor and
            // its chrome so the whole window has a uniform translucency.
            textView?.drawsBackground = false
            textView?.backgroundColor = .clear
            tabBarView?.backgroundAlpha = 0
            lineNumberGutter?.backgroundAlpha = 0
        }

        window.contentView?.needsDisplay = true
        textView?.needsDisplay = true
        tabBarView?.needsDisplay = true
        lineNumberGutter?.needsDisplay = true
    }

    /// Re-apply the current appearance after a theme change so the
    /// translucent text-view background picks up the new theme colours.
    private func reapplyCurrentAppearanceStyle() {
        applyAppearanceStyle(EditorSettings.appearanceStyle)
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
        window?.title = "NotepadMacMac — \(doc.fileURL?.path ?? doc.title)"
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
    func documentManager(_ m: DocumentManager, didRemoveDocumentAt i: Int) {
        tabBarView.removeTab(at: i)
    }
    func documentManager(_ m: DocumentManager, didSwitchToDocument doc: Document, at i: Int) {
        tabBarView.selectTab(at: i); loadDocumentIntoEditor(doc)
        // Drain any queued external-change prompt for the doc we just
        // switched to, so the user sees it the moment they look at it.
        DispatchQueue.main.async { [weak self] in
            self?.processPendingExternalChanges()
        }
    }
    func documentManager(_ m: DocumentManager, didUpdateDocument doc: Document, at i: Int) {
        tabBarView.updateTab(at: i, title: doc.displayTitle, isModified: doc.isModified)
    }
    func documentManager(_ m: DocumentManager, didDetectExternalChangeFor doc: Document, wasDeleted: Bool) {
        // We re-derive `wasDeleted` from a fresh stat at drain time,
        // so the Bool here is unused — multiple watcher events for
        // the same doc collapse into one Set entry.
        externalChangeQueue.insert(doc.id)
        processPendingExternalChanges()
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
