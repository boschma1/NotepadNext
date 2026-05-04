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
        window.title = "NotepadNext"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)

        mainController = MainWindowController(window: window)
        mainController.setupContent(createEmptyTab: pendingFiles.isEmpty)

        // Apply saved theme to editor
        ThemeManager.shared.applyTheme()

        // Restore previous session (only if no files pending)
        if pendingFiles.isEmpty {
            SessionManager.shared.restoreSession(into: mainController.documentManager)
        }

        // Enable drag-and-drop of files onto the window
        window.registerForDraggedTypes([.fileURL])

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Open any files that were requested before launch completed
        for f in pendingFiles {
            mainController.documentManager.openDocument(at: URL(fileURLWithPath: f))
        }
        pendingFiles.removeAll()
    }

    private var pendingFiles: [String] = []

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if mainController != nil {
            mainController.documentManager.openDocument(at: URL(fileURLWithPath: filename))
        } else {
            pendingFiles.append(filename)
        }
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for f in filenames {
            if mainController != nil {
                mainController.documentManager.openDocument(at: URL(fileURLWithPath: f))
            } else {
                pendingFiles.append(f)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
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
}
