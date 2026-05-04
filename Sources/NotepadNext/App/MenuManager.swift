import AppKit

class MenuManager {

    func setupMainMenu() {
        let mainMenu = NSMenu()

        mainMenu.addItem(createAppMenu())
        mainMenu.addItem(createFileMenu())
        mainMenu.addItem(createEditMenu())
        mainMenu.addItem(createSearchMenu())
        mainMenu.addItem(createViewMenu())
        mainMenu.addItem(createWindowMenu())
        mainMenu.addItem(createHelpMenu())

        NSApp.mainMenu = mainMenu
    }

    // MARK: - App Menu

    private func createAppMenu() -> NSMenuItem {
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        appMenu.addItem(withTitle: "About NotepadNext",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Settings…",
                                   action: nil,
                                   keyEquivalent: ",")
        appMenu.addItem(prefsItem)
        appMenu.addItem(.separator())

        appMenu.addItem(withTitle: "Hide NotepadNext",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")

        let hideOthers = NSMenuItem(title: "Hide Others",
                                    action: #selector(NSApplication.hideOtherApplications(_:)),
                                    keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)

        appMenu.addItem(withTitle: "Show All",
                        action: #selector(NSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())

        appMenu.addItem(withTitle: "Quit NotepadNext",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        appMenuItem.submenu = appMenu
        return appMenuItem
    }

    // MARK: - File Menu

    private func createFileMenu() -> NSMenuItem {
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")

        fileMenu.addItem(withTitle: "New",
                         action: #selector(AppDelegate.newDocument(_:)),
                         keyEquivalent: "n")

        fileMenu.addItem(withTitle: "Open…",
                         action: #selector(AppDelegate.openDocument(_:)),
                         keyEquivalent: "o")

        fileMenu.addItem(.separator())

        fileMenu.addItem(withTitle: "Save",
                         action: #selector(AppDelegate.saveDocument(_:)),
                         keyEquivalent: "s")

        let saveAsItem = NSMenuItem(title: "Save As…",
                                    action: #selector(AppDelegate.saveDocumentAs(_:)),
                                    keyEquivalent: "S")
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(saveAsItem)

        fileMenu.addItem(.separator())

        fileMenu.addItem(withTitle: "Close Tab",
                         action: #selector(AppDelegate.closeTab(_:)),
                         keyEquivalent: "w")

        fileMenuItem.submenu = fileMenu
        return fileMenuItem
    }

    // MARK: - Edit Menu

    private func createEditMenu() -> NSMenuItem {
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")

        editMenu.addItem(withTitle: "Undo",
                         action: Selector(("undo:")),
                         keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo",
                         action: Selector(("redo:")),
                         keyEquivalent: "Z")
        editMenu.addItem(.separator())

        editMenu.addItem(withTitle: "Cut",
                         action: #selector(NSText.cut(_:)),
                         keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",
                         action: #selector(NSText.copy(_:)),
                         keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",
                         action: #selector(NSText.paste(_:)),
                         keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All",
                         action: #selector(NSText.selectAll(_:)),
                         keyEquivalent: "a")

        editMenuItem.submenu = editMenu
        return editMenuItem
    }

    // MARK: - Search Menu

    private func createSearchMenu() -> NSMenuItem {
        let searchMenuItem = NSMenuItem()
        let searchMenu = NSMenu(title: "Search")

        searchMenu.addItem(withTitle: "Find…",
                           action: #selector(NSTextView.performFindPanelAction(_:)),
                           keyEquivalent: "f")

        let replaceItem = NSMenuItem(title: "Replace…",
                                     action: nil,
                                     keyEquivalent: "h")
        searchMenu.addItem(replaceItem)

        searchMenu.addItem(.separator())

        let goToItem = NSMenuItem(title: "Go to Line…",
                                  action: nil,
                                  keyEquivalent: "g")
        searchMenu.addItem(goToItem)

        searchMenuItem.submenu = searchMenu
        return searchMenuItem
    }

    // MARK: - View Menu

    private func createViewMenu() -> NSMenuItem {
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")

        viewMenu.addItem(withTitle: "Show Toolbar",
                         action: nil,
                         keyEquivalent: "")
        viewMenu.addItem(withTitle: "Show Status Bar",
                         action: nil,
                         keyEquivalent: "")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Word Wrap",
                         action: nil,
                         keyEquivalent: "")
        viewMenu.addItem(.separator())

        let zoomIn = NSMenuItem(title: "Zoom In",
                                action: nil,
                                keyEquivalent: "+")
        viewMenu.addItem(zoomIn)

        let zoomOut = NSMenuItem(title: "Zoom Out",
                                 action: nil,
                                 keyEquivalent: "-")
        viewMenu.addItem(zoomOut)

        let zoomReset = NSMenuItem(title: "Reset Zoom",
                                   action: nil,
                                   keyEquivalent: "0")
        viewMenu.addItem(zoomReset)

        viewMenuItem.submenu = viewMenu
        return viewMenuItem
    }

    // MARK: - Window Menu

    private func createWindowMenu() -> NSMenuItem {
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")

        windowMenu.addItem(withTitle: "Minimize",
                           action: #selector(NSWindow.miniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom",
                           action: #selector(NSWindow.zoom(_:)),
                           keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front",
                           action: #selector(NSApplication.arrangeInFront(_:)),
                           keyEquivalent: "")

        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu
        return windowMenuItem
    }

    // MARK: - Help Menu

    private func createHelpMenu() -> NSMenuItem {
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")

        helpMenu.addItem(withTitle: "NotepadNext Help",
                         action: nil,
                         keyEquivalent: "")

        helpMenuItem.submenu = helpMenu
        NSApp.helpMenu = helpMenu
        return helpMenuItem
    }
}
