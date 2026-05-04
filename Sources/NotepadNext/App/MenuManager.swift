import AppKit

class MenuManager {

    func setupMainMenu() {
        let mainMenu = NSMenu()

        mainMenu.addItem(createAppMenu())
        mainMenu.addItem(createFileMenu())
        mainMenu.addItem(createEditMenu())
        mainMenu.addItem(createSearchMenu())
        mainMenu.addItem(createViewMenu())
        mainMenu.addItem(createEncodingMenu())
        mainMenu.addItem(createLanguageMenu())
        mainMenu.addItem(createMacroMenu())
        mainMenu.addItem(createToolsMenu())
        mainMenu.addItem(createRunMenu())
        mainMenu.addItem(createPluginsMenu())
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
                                   action: #selector(AppDelegate.showPreferences(_:)),
                                   keyEquivalent: ",")
        appMenu.addItem(prefsItem)

        appMenu.addItem(withTitle: "Shortcut Mapper…",
                        action: #selector(AppDelegate.showShortcutMapper(_:)),
                        keyEquivalent: "")
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

        editMenu.addItem(.separator())

        // Line operations
        let lineOpsMenu = NSMenu(title: "Line Operations")
        lineOpsMenu.addItem(withTitle: "Duplicate Line",
                            action: #selector(AppDelegate.duplicateLine(_:)),
                            keyEquivalent: "d")
        lineOpsMenu.addItem(withTitle: "Delete Line",
                            action: #selector(AppDelegate.deleteLine(_:)),
                            keyEquivalent: "L")
        let moveUp = NSMenuItem(title: "Move Line Up",
                                action: #selector(AppDelegate.moveLineUp(_:)),
                                keyEquivalent: String(UnicodeScalar(NSUpArrowFunctionKey)!))
        moveUp.keyEquivalentModifierMask = [.command, .shift]
        lineOpsMenu.addItem(moveUp)
        let moveDown = NSMenuItem(title: "Move Line Down",
                                  action: #selector(AppDelegate.moveLineDown(_:)),
                                  keyEquivalent: String(UnicodeScalar(NSDownArrowFunctionKey)!))
        moveDown.keyEquivalentModifierMask = [.command, .shift]
        lineOpsMenu.addItem(moveDown)

        let lineOpsItem = NSMenuItem(title: "Line Operations", action: nil, keyEquivalent: "")
        lineOpsItem.submenu = lineOpsMenu
        editMenu.addItem(lineOpsItem)

        // Case conversion
        let caseMenu = NSMenu(title: "Convert Case")
        caseMenu.addItem(withTitle: "UPPERCASE",
                         action: #selector(AppDelegate.convertToUpperCase(_:)),
                         keyEquivalent: "U")
        caseMenu.addItem(withTitle: "lowercase",
                         action: #selector(AppDelegate.convertToLowerCase(_:)),
                         keyEquivalent: "u")
        let caseItem = NSMenuItem(title: "Convert Case", action: nil, keyEquivalent: "")
        caseItem.submenu = caseMenu
        editMenu.addItem(caseItem)

        editMenu.addItem(.separator())

        let commentItem = NSMenuItem(title: "Toggle Comment",
                                     action: #selector(AppDelegate.toggleComment(_:)),
                                     keyEquivalent: "/")
        editMenu.addItem(commentItem)

        editMenu.addItem(.separator())

        editMenu.addItem(withTitle: "Trim Trailing Whitespace",
                         action: #selector(AppDelegate.trimTrailingWhitespace(_:)),
                         keyEquivalent: "")

        editMenuItem.submenu = editMenu
        return editMenuItem
    }

    // MARK: - Search Menu

    private func createSearchMenu() -> NSMenuItem {
        let searchMenuItem = NSMenuItem()
        let searchMenu = NSMenu(title: "Search")

        searchMenu.addItem(withTitle: "Find…",
                           action: #selector(AppDelegate.showFindReplace(_:)),
                           keyEquivalent: "f")

        let replaceItem = NSMenuItem(title: "Replace…",
                                     action: #selector(AppDelegate.showFindReplace(_:)),
                                     keyEquivalent: "h")
        searchMenu.addItem(replaceItem)

        searchMenu.addItem(.separator())

        let goToItem = NSMenuItem(title: "Go to Line…",
                                  action: #selector(AppDelegate.showGoToLine(_:)),
                                  keyEquivalent: "g")
        searchMenu.addItem(goToItem)

        searchMenu.addItem(.separator())

        let findInFiles = NSMenuItem(title: "Find in Files…",
                                     action: #selector(AppDelegate.showFindInFiles(_:)),
                                     keyEquivalent: "F")
        findInFiles.keyEquivalentModifierMask = [.command, .shift]
        searchMenu.addItem(findInFiles)

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
                         action: #selector(AppDelegate.toggleWordWrap(_:)),
                         keyEquivalent: "")
        viewMenu.addItem(.separator())

        viewMenu.addItem(withTitle: "Folder as Workspace",
                         action: #selector(AppDelegate.toggleFolderPanel(_:)),
                         keyEquivalent: "")
        viewMenu.addItem(withTitle: "Open Folder…",
                         action: #selector(AppDelegate.openFolderAsWorkspace(_:)),
                         keyEquivalent: "")
        viewMenu.addItem(withTitle: "Document Map",
                         action: #selector(AppDelegate.toggleDocumentMap(_:)),
                         keyEquivalent: "")
        viewMenu.addItem(withTitle: "Document List",
                         action: #selector(AppDelegate.toggleDocumentList(_:)),
                         keyEquivalent: "")
        viewMenu.addItem(withTitle: "Function List",
                         action: #selector(AppDelegate.toggleFunctionList(_:)),
                         keyEquivalent: "")
        viewMenu.addItem(withTitle: "Project Panel",
                         action: #selector(AppDelegate.toggleProjectPanel(_:)),
                         keyEquivalent: "")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Split View",
                         action: #selector(AppDelegate.toggleSplitView(_:)),
                         keyEquivalent: "")
        viewMenu.addItem(withTitle: "Rotate Split",
                         action: #selector(AppDelegate.rotateSplitView(_:)),
                         keyEquivalent: "")
        viewMenu.addItem(.separator())

        // Theme submenu
        let themeMenu = NSMenu(title: "Theme")
        for theme in ThemeManager.builtInThemes {
            let item = NSMenuItem(title: theme.name, action: #selector(AppDelegate.setTheme(_:)), keyEquivalent: "")
            item.representedObject = theme.name
            themeMenu.addItem(item)
        }
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        viewMenu.addItem(themeItem)

        viewMenu.addItem(.separator())

        let zoomIn = NSMenuItem(title: "Zoom In",
                                action: #selector(AppDelegate.zoomIn(_:)),
                                keyEquivalent: "+")
        viewMenu.addItem(zoomIn)

        let zoomOut = NSMenuItem(title: "Zoom Out",
                                 action: #selector(AppDelegate.zoomOut(_:)),
                                 keyEquivalent: "-")
        viewMenu.addItem(zoomOut)

        let zoomReset = NSMenuItem(title: "Reset Zoom",
                                   action: #selector(AppDelegate.zoomReset(_:)),
                                   keyEquivalent: "0")
        viewMenu.addItem(zoomReset)

        viewMenuItem.submenu = viewMenu
        return viewMenuItem
    }

    // MARK: - Encoding Menu

    private func createEncodingMenu() -> NSMenuItem {
        let encMenuItem = NSMenuItem()
        let encMenu = NSMenu(title: "Encoding")

        let encodings: [(String, String)] = [
            ("UTF-8", "utf8"),
            ("UTF-8 with BOM", "utf8bom"),
            ("UTF-16 LE", "utf16le"),
            ("UTF-16 BE", "utf16be"),
            ("ASCII", "ascii"),
            ("ISO 8859-1 (Latin 1)", "isoLatin1"),
            ("Windows-1252", "windowsCP1252"),
            ("Mac OS Roman", "macOSRoman"),
        ]

        for (title, id) in encodings {
            let item = NSMenuItem(title: title, action: #selector(AppDelegate.setEncoding(_:)), keyEquivalent: "")
            item.representedObject = id
            encMenu.addItem(item)
        }

        encMenu.addItem(.separator())

        let convertMenu = NSMenu(title: "Convert to")
        for (title, id) in encodings {
            let item = NSMenuItem(title: "Convert to \(title)",
                                  action: #selector(AppDelegate.convertEncoding(_:)),
                                  keyEquivalent: "")
            item.representedObject = id
            convertMenu.addItem(item)
        }
        let convertItem = NSMenuItem(title: "Convert to…", action: nil, keyEquivalent: "")
        convertItem.submenu = convertMenu
        encMenu.addItem(convertItem)

        encMenu.addItem(.separator())

        let lineEndingMenu = NSMenu(title: "Line Endings")
        for (title, id) in [("Unix (LF)", "LF"), ("Windows (CRLF)", "CRLF"), ("Classic Mac (CR)", "CR")] {
            let item = NSMenuItem(title: title, action: #selector(AppDelegate.setLineEnding(_:)), keyEquivalent: "")
            item.representedObject = id
            lineEndingMenu.addItem(item)
        }
        let lineEndingItem = NSMenuItem(title: "Line Endings", action: nil, keyEquivalent: "")
        lineEndingItem.submenu = lineEndingMenu
        encMenu.addItem(lineEndingItem)

        encMenuItem.submenu = encMenu
        return encMenuItem
    }

    // MARK: - Macro Menu

    private func createMacroMenu() -> NSMenuItem {
        let macroMenuItem = NSMenuItem()
        let macroMenu = NSMenu(title: "Macro")

        let startStop = NSMenuItem(title: "Start/Stop Recording",
                                   action: #selector(AppDelegate.macroStartStop(_:)),
                                   keyEquivalent: "r")
        startStop.keyEquivalentModifierMask = [.command, .shift]
        macroMenu.addItem(startStop)

        let playback = NSMenuItem(title: "Playback",
                                  action: #selector(AppDelegate.macroPlayback(_:)),
                                  keyEquivalent: "p")
        playback.keyEquivalentModifierMask = [.command, .shift]
        macroMenu.addItem(playback)

        macroMenu.addItem(withTitle: "Run Multiple Times…",
                          action: #selector(AppDelegate.macroPlayMultiple(_:)),
                          keyEquivalent: "")

        macroMenuItem.submenu = macroMenu
        return macroMenuItem
    }

    // MARK: - Language Menu

    private func createLanguageMenu() -> NSMenuItem {
        let langMenuItem = NSMenuItem()
        let langMenu = NSMenu(title: "Language")

        let languages: [(String, [String])] = [
            ("Common", ["Normal Text", "C", "C++", "C#", "CSS", "Go", "HTML", "Java",
                        "JavaScript", "JSON", "Markdown", "Objective-C", "PHP", "Python",
                        "Ruby", "Rust", "Shell", "SQL", "Swift", "TypeScript", "XML", "YAML"]),
        ]

        for (group, langs) in languages {
            if langMenu.items.count > 0 {
                langMenu.addItem(.separator())
            }
            for lang in langs {
                let item = NSMenuItem(title: lang,
                                      action: #selector(AppDelegate.setLanguage(_:)),
                                      keyEquivalent: "")
                item.representedObject = lang
                langMenu.addItem(item)
            }
        }

        // Add UDL languages
        let udlLangs = UDLManager.shared.languages
        if !udlLangs.isEmpty {
            langMenu.addItem(.separator())
            for udl in udlLangs {
                let item = NSMenuItem(title: "⚙ \(udl.name)",
                                      action: #selector(AppDelegate.setLanguage(_:)),
                                      keyEquivalent: "")
                item.representedObject = udl.name
                langMenu.addItem(item)
            }
        }

        langMenu.addItem(.separator())
        langMenu.addItem(withTitle: "Define Your Language…",
                         action: #selector(AppDelegate.showUDLEditor(_:)),
                         keyEquivalent: "")

        langMenuItem.submenu = langMenu
        return langMenuItem
    }

    // MARK: - Tools Menu

    private func createToolsMenu() -> NSMenuItem {
        let toolsMenuItem = NSMenuItem()
        let toolsMenu = NSMenu(title: "Tools")

        toolsMenu.addItem(withTitle: "Generate Hash…",
                          action: #selector(AppDelegate.showHashTools(_:)),
                          keyEquivalent: "")

        toolsMenu.addItem(.separator())

        let autoComplete = NSMenuItem(title: "Auto-Complete",
                                      action: #selector(AppDelegate.triggerAutoComplete(_:)),
                                      keyEquivalent: " ")
        autoComplete.keyEquivalentModifierMask = [.control]
        toolsMenu.addItem(autoComplete)

        toolsMenuItem.submenu = toolsMenu
        return toolsMenuItem
    }

    // MARK: - Run Menu

    private func createRunMenu() -> NSMenuItem {
        let runMenuItem = NSMenuItem()
        let runMenu = NSMenu(title: "Run")

        runMenu.addItem(withTitle: "Open in Terminal",
                        action: #selector(AppDelegate.runInTerminal(_:)),
                        keyEquivalent: "")
        runMenu.addItem(withTitle: "Open in Default App",
                        action: #selector(AppDelegate.openInDefaultApp(_:)),
                        keyEquivalent: "")
        runMenu.addItem(withTitle: "Reveal in Finder",
                        action: #selector(AppDelegate.revealInFinder(_:)),
                        keyEquivalent: "")

        runMenuItem.submenu = runMenu
        return runMenuItem
    }

    // MARK: - Plugins Menu

    private func createPluginsMenu() -> NSMenuItem {
        let pluginsMenuItem = NSMenuItem()
        let pluginsMenu = NSMenu(title: "Plugins")

        pluginsMenu.addItem(withTitle: "Plugin Manager…",
                            action: #selector(AppDelegate.showPluginManager(_:)),
                            keyEquivalent: "")
        pluginsMenu.addItem(.separator())

        // Add items from loaded plugins
        for item in PluginManager.shared.pluginMenuItems() {
            pluginsMenu.addItem(item)
        }

        if PluginManager.shared.loadedPlugins.isEmpty {
            let noPlugins = NSMenuItem(title: "(No plugins installed)", action: nil, keyEquivalent: "")
            noPlugins.isEnabled = false
            pluginsMenu.addItem(noPlugins)
        }

        pluginsMenuItem.submenu = pluginsMenu
        return pluginsMenuItem
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
