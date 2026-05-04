import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private var mainWindowController: MainWindowController?
    private var menuManager: MenuManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuManager = MenuManager()
        menuManager?.setupMainMenu()

        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - File actions called from menu

    @objc func newDocument(_ sender: Any?) {
        mainWindowController?.documentManager.createNewDocument()
    }

    @objc func openDocument(_ sender: Any?) {
        guard let window = mainWindowController?.window else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            for url in panel.urls {
                self?.mainWindowController?.documentManager.openDocument(at: url)
            }
        }
    }

    @objc func saveDocument(_ sender: Any?) {
        mainWindowController?.saveCurrentDocument()
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        mainWindowController?.saveCurrentDocumentAs()
    }

    @objc func closeTab(_ sender: Any?) {
        mainWindowController?.closeCurrentTab()
    }

    // MARK: - Edit actions

    @objc func duplicateLine(_ sender: Any?) {
        mainWindowController?.editorCommands?.duplicateLine()
    }

    @objc func deleteLine(_ sender: Any?) {
        mainWindowController?.editorCommands?.deleteLine()
    }

    @objc func moveLineUp(_ sender: Any?) {
        mainWindowController?.editorCommands?.moveLineUp()
    }

    @objc func moveLineDown(_ sender: Any?) {
        mainWindowController?.editorCommands?.moveLineDown()
    }

    @objc func convertToUpperCase(_ sender: Any?) {
        mainWindowController?.editorCommands?.convertToUpperCase()
    }

    @objc func convertToLowerCase(_ sender: Any?) {
        mainWindowController?.editorCommands?.convertToLowerCase()
    }

    @objc func toggleComment(_ sender: Any?) {
        mainWindowController?.editorCommands?.toggleLineComment()
    }

    @objc func trimTrailingWhitespace(_ sender: Any?) {
        mainWindowController?.editorCommands?.trimTrailingWhitespace()
    }

    // MARK: - Search actions

    @objc func showFindReplace(_ sender: Any?) {
        mainWindowController?.showFindReplace()
    }

    @objc func showGoToLine(_ sender: Any?) {
        mainWindowController?.showGoToLine()
    }

    // MARK: - Language actions

    @objc func setLanguage(_ sender: NSMenuItem) {
        guard let language = sender.representedObject as? String else { return }
        mainWindowController?.setLanguage(language)
    }
}
