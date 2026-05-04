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
}
