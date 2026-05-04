import AppKit

/// Preferences dialog with multiple tabs.
class PreferencesWindowController: NSWindowController {

    private var tabView: NSTabView!

    convenience init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "Settings"
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let cv = window?.contentView else { return }

        tabView = NSTabView(frame: cv.bounds)
        tabView.autoresizingMask = [.width, .height]

        tabView.addTabViewItem(createGeneralTab())
        tabView.addTabViewItem(createEditorTab())
        tabView.addTabViewItem(createAppearanceTab())

        cv.addSubview(tabView)
    }

    private func createGeneralTab() -> NSTabViewItem {
        let tab = NSTabViewItem(identifier: "general")
        tab.label = "General"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 340))

        var y: CGFloat = 300

        let rememberSession = NSButton(checkboxWithTitle: "Remember session for next launch", target: nil, action: nil)
        rememberSession.state = .on
        rememberSession.frame = NSRect(x: 20, y: y, width: 400, height: 20)
        view.addSubview(rememberSession)
        y -= 30

        let exitOnLastTab = NSButton(checkboxWithTitle: "Exit when last tab is closed", target: nil, action: nil)
        exitOnLastTab.state = .on
        exitOnLastTab.frame = NSRect(x: 20, y: y, width: 400, height: 20)
        view.addSubview(exitOnLastTab)
        y -= 30

        let doubleClickClose = NSButton(checkboxWithTitle: "Double-click tab to close", target: nil, action: nil)
        doubleClickClose.frame = NSRect(x: 20, y: y, width: 400, height: 20)
        view.addSubview(doubleClickClose)
        y -= 40

        let recentLabel = NSTextField(labelWithString: "Recent files history size:")
        recentLabel.frame = NSRect(x: 20, y: y, width: 180, height: 20)
        view.addSubview(recentLabel)

        let recentField = NSTextField(frame: NSRect(x: 200, y: y, width: 60, height: 22))
        recentField.stringValue = "10"
        view.addSubview(recentField)

        tab.view = view
        return tab
    }

    private func createEditorTab() -> NSTabViewItem {
        let tab = NSTabViewItem(identifier: "editor")
        tab.label = "Editor"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 340))

        var y: CGFloat = 300

        let fontLabel = NSTextField(labelWithString: "Font size:")
        fontLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(fontLabel)

        let fontField = NSTextField(frame: NSRect(x: 120, y: y, width: 60, height: 22))
        fontField.stringValue = "13"
        view.addSubview(fontField)
        y -= 30

        let tabSizeLabel = NSTextField(labelWithString: "Tab size:")
        tabSizeLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(tabSizeLabel)

        let tabSizeField = NSTextField(frame: NSRect(x: 120, y: y, width: 60, height: 22))
        tabSizeField.stringValue = "4"
        view.addSubview(tabSizeField)
        y -= 30

        let useSpaces = NSButton(checkboxWithTitle: "Use spaces instead of tabs", target: nil, action: nil)
        useSpaces.frame = NSRect(x: 20, y: y, width: 400, height: 20)
        view.addSubview(useSpaces)
        y -= 30

        let wordWrap = NSButton(checkboxWithTitle: "Word wrap by default", target: nil, action: nil)
        wordWrap.frame = NSRect(x: 20, y: y, width: 400, height: 20)
        view.addSubview(wordWrap)
        y -= 30

        let showLineNumbers = NSButton(checkboxWithTitle: "Show line numbers", target: nil, action: nil)
        showLineNumbers.state = .on
        showLineNumbers.frame = NSRect(x: 20, y: y, width: 400, height: 20)
        view.addSubview(showLineNumbers)
        y -= 30

        let highlightLine = NSButton(checkboxWithTitle: "Highlight current line", target: nil, action: nil)
        highlightLine.state = .on
        highlightLine.frame = NSRect(x: 20, y: y, width: 400, height: 20)
        view.addSubview(highlightLine)
        y -= 30

        let autoComplete = NSButton(checkboxWithTitle: "Enable auto-completion", target: nil, action: nil)
        autoComplete.state = .on
        autoComplete.frame = NSRect(x: 20, y: y, width: 400, height: 20)
        view.addSubview(autoComplete)

        tab.view = view
        return tab
    }

    private func createAppearanceTab() -> NSTabViewItem {
        let tab = NSTabViewItem(identifier: "appearance")
        tab.label = "Appearance"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 340))

        var y: CGFloat = 300

        let themeLabel = NSTextField(labelWithString: "Theme:")
        themeLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(themeLabel)

        let themePopup = NSPopUpButton(frame: NSRect(x: 120, y: y - 2, width: 200, height: 24))
        themePopup.addItems(withTitles: ["System", "Light", "Dark"])
        themePopup.target = self
        themePopup.action = #selector(themeChanged(_:))
        view.addSubview(themePopup)
        y -= 40

        let encodingLabel = NSTextField(labelWithString: "Default encoding:")
        encodingLabel.frame = NSRect(x: 20, y: y, width: 120, height: 20)
        view.addSubview(encodingLabel)

        let encodingPopup = NSPopUpButton(frame: NSRect(x: 150, y: y - 2, width: 200, height: 24))
        encodingPopup.addItems(withTitles: ["UTF-8", "UTF-8 with BOM", "ASCII", "ISO 8859-1", "Windows-1252"])
        view.addSubview(encodingPopup)
        y -= 40

        let lineEndingLabel = NSTextField(labelWithString: "Default line ending:")
        lineEndingLabel.frame = NSRect(x: 20, y: y, width: 130, height: 20)
        view.addSubview(lineEndingLabel)

        let lineEndingPopup = NSPopUpButton(frame: NSRect(x: 150, y: y - 2, width: 200, height: 24))
        lineEndingPopup.addItems(withTitles: ["Unix (LF)", "Windows (CRLF)", "Classic Mac (CR)"])
        view.addSubview(lineEndingPopup)

        tab.view = view
        return tab
    }

    @objc private func themeChanged(_ sender: NSPopUpButton) {
        switch sender.titleOfSelectedItem {
        case "Light": ThemeManager.shared.currentTheme = .light
        case "Dark": ThemeManager.shared.currentTheme = .dark
        default: ThemeManager.shared.currentTheme = .system
        }
    }

    func showAndFocus() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
