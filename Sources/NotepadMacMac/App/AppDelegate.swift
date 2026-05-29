import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    var mainController: MainWindowController!
    private var menuManager: MenuManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Restore saved theme before building UI
        ThemeManager.shared.loadSettings()
        UDLManager.shared.load()
        PluginManager.shared.loadPlugins()

        menuManager = MenuManager()
        menuManager?.setupMainMenu()

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotepadMacMac"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)

        mainController = MainWindowController(window: window)
        let hasSession = SessionManager.shared.hasSession()
        mainController.setupContent(createEmptyTab: pendingFiles.isEmpty && !hasSession)

        // Apply saved theme to editor
        ThemeManager.shared.applyTheme()

        // Restore previous session (only if no files pending)
        if pendingFiles.isEmpty {
            SessionManager.shared.restoreSession(into: mainController.documentManager)
        }

        // Enable drag-and-drop of files onto the window
        window.registerForDraggedTypes([.fileURL])

        window.makeKeyAndOrderFront(nil)

        // Position window if --origin was specified
        if let origin = parsedOrigin() {
            window.setFrameOrigin(origin)
        }

        NSApp.activate(ignoringOtherApps: true)

        // Open any files that were requested before launch completed
        let customTitle = parsedTitle()
        for f in pendingFiles {
            if let doc = mainController.documentManager.openDocument(at: URL(fileURLWithPath: f)) {
                if let title = customTitle {
                    doc.title = title
                    if f.hasPrefix(FileManager.default.temporaryDirectory.path) {
                        doc.fileURL = nil
                        doc.isModified = true
                    }
                    // Update tab display
                    if let idx = mainController.documentManager.documents.firstIndex(where: { $0.id == doc.id }) {
                        mainController.documentManager.delegate?.documentManager(
                            mainController.documentManager, didUpdateDocument: doc, at: idx)
                        mainController.documentManager.switchToDocument(at: idx)
                    }
                }
            }
        }
        pendingFiles.removeAll()

        // Safety net: regardless of session state, command-line args, or
        // restore failures, the user must always end up with at least
        // one tab. Otherwise the window is unusably empty and actions
        // like Cmd+S silently no-op because there's no active document.
        if mainController.documentManager.documents.isEmpty {
            mainController.documentManager.createNewDocument()
        }
    }

    private var pendingFiles: [String] = []

    private func parsedTitle() -> String? {
        let args = CommandLine.arguments
        if let titleIdx = args.firstIndex(of: "--title"), titleIdx + 1 < args.count {
            return args[titleIdx + 1]
        }
        return nil
    }

    private func parsedOrigin() -> NSPoint? {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--origin"), idx + 1 < args.count {
            let parts = args[idx + 1].split(separator: ",")
            if parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]) {
                return NSPoint(x: x, y: y)
            }
        }
        return nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if isSpecialArg(filename) { return true }
        if mainController != nil {
            mainController.documentManager.openDocument(at: URL(fileURLWithPath: filename))
        } else {
            pendingFiles.append(filename)
        }
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for f in filenames {
            if isSpecialArg(f) { continue }
            if mainController != nil {
                mainController.documentManager.openDocument(at: URL(fileURLWithPath: f))
            } else {
                pendingFiles.append(f)
            }
        }
    }

    private func isSpecialArg(_ filename: String) -> Bool {
        let args = CommandLine.arguments
        for flag in ["--title", "--origin"] {
            if let idx = args.firstIndex(of: flag), idx + 1 < args.count, args[idx + 1] == filename {
                return true
            }
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Sync current editor content to active document before saving session
        if let doc = mainController.documentManager.activeDocument {
            doc.content = mainController.textView.string
        }
        SessionManager.shared.saveSession(from: mainController.documentManager)
    }

    @objc func newDocument(_ sender: Any?) { mainController.documentManager.createNewDocument() }
    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            for url in panel.urls { self?.mainController.documentManager.openDocument(at: url) }
        }
    }
    @objc func saveDocument(_ sender: Any?) { mainController.saveCurrentDocument() }
    @objc func saveDocumentAs(_ sender: Any?) { mainController.saveCurrentDocumentAs() }
    @objc func closeTab(_ sender: Any?) { mainController.closeCurrentTab() }
    @objc func duplicateLine(_ sender: Any?) { mainController.editorCommands?.duplicateLine() }
    @objc func deleteLine(_ sender: Any?) { mainController.editorCommands?.deleteLine() }
    @objc func moveLineUp(_ sender: Any?) { mainController.editorCommands?.moveLineUp() }
    @objc func moveLineDown(_ sender: Any?) { mainController.editorCommands?.moveLineDown() }
    @objc func convertToUpperCase(_ sender: Any?) { mainController.editorCommands?.convertToUpperCase() }
    @objc func convertToLowerCase(_ sender: Any?) { mainController.editorCommands?.convertToLowerCase() }
    @objc func toggleComment(_ sender: Any?) { mainController.editorCommands?.toggleLineComment() }
    @objc func trimTrailingWhitespace(_ sender: Any?) { mainController.editorCommands?.trimTrailingWhitespace() }
    @objc func showFindReplace(_ sender: Any?) { mainController.showFindReplace() }
    @objc func showGoToLine(_ sender: Any?) { mainController.showGoToLine() }
    @objc func setLanguage(_ sender: NSMenuItem) {
        guard let language = sender.representedObject as? String else { return }
        mainController.setLanguage(language)
    }
    @objc func setEncoding(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        mainController.setEncodingLabel(id)
    }
    @objc func convertEncoding(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        mainController.convertEncoding(to: id)
    }
    @objc func setLineEnding(_ sender: NSMenuItem) {
        guard let ending = sender.representedObject as? String else { return }
        mainController.setLineEnding(ending)
    }
    @objc func zoomIn(_ sender: Any?) { mainController.zoom(delta: 1) }
    @objc func zoomOut(_ sender: Any?) { mainController.zoom(delta: -1) }
    @objc func zoomReset(_ sender: Any?) { mainController.zoomReset() }
    @objc func toggleWordWrap(_ sender: Any?) { mainController.toggleWordWrap() }
    @objc func toggleFolderPanel(_ sender: Any?) { mainController.toggleFolderPanel() }
    @objc func openFolderAsWorkspace(_ sender: Any?) { mainController.openFolderInWorkspace() }
    @objc func toggleDocumentMap(_ sender: Any?) { mainController.toggleDocumentMap() }
    @objc func toggleDocumentList(_ sender: Any?) { mainController.toggleDocumentList() }
    @objc func toggleFunctionList(_ sender: Any?) { mainController.toggleFunctionList() }
    @objc func toggleProjectPanel(_ sender: Any?) { mainController.toggleProjectPanel() }
    @objc func toggleSplitView(_ sender: Any?) { mainController.toggleSplitView() }
    @objc func rotateSplitView(_ sender: Any?) { mainController.rotateSplitView() }
    @objc func showHashTools(_ sender: Any?) { mainController.showHashTools() }
    @objc func triggerAutoComplete(_ sender: Any?) { mainController.triggerAutoComplete() }
    @objc func showFindInFiles(_ sender: Any?) { mainController.showFindInFiles() }
    @objc func toggleFormattingMarks(_ sender: Any?) { mainController.toggleFormattingMarks() }
    @objc func showAbout(_ sender: Any?) {
        let credits = NSAttributedString(
            string: "Developed by Markus Bosch",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
    @objc func showPreferences(_ sender: Any?) { mainController.showPreferences() }
    @objc func runInTerminal(_ sender: Any?) { mainController.runInTerminal() }
    @objc func openInDefaultApp(_ sender: Any?) { mainController.openInDefaultApp() }
    @objc func revealInFinder(_ sender: Any?) { mainController.revealInFinder() }
    @objc func showShortcutMapper(_ sender: Any?) { mainController.showShortcutMapper() }
    @objc func showPluginManager(_ sender: Any?) { mainController.showPluginManager() }
    @objc func showUDLEditor(_ sender: Any?) { mainController.showUDLEditor() }
    @objc func setTheme(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        if let theme = ThemeManager.builtInThemes.first(where: { $0.name == name }) {
            ThemeManager.shared.currentTheme = theme
        }
    }
    @objc func macroStartStop(_ sender: Any?) {
        if MacroEngine.shared.isRecording {
            MacroEngine.shared.stopRecording()
        } else {
            MacroEngine.shared.startRecording()
        }
    }
    @objc func macroPlayback(_ sender: Any?) {
        MacroEngine.shared.playback(on: mainController.textView)
    }
    @objc func macroPlayMultiple(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Run Macro Multiple Times"
        alert.informativeText = "How many times?"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        field.stringValue = "10"
        alert.accessoryView = field
        alert.addButton(withTitle: "Run")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn, let n = Int(field.stringValue), n > 0 {
            MacroEngine.shared.playbackMultiple(times: n, on: mainController.textView)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleFormattingMarks(_:)) {
            menuItem.state = EditorSettings.showFormattingMarks ? .on : .off
        }
        return true
    }
}
