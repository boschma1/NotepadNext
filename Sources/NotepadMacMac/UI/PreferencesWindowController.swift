import AppKit

class PreferencesWindowController: NSWindowController {

    private var tabView: NSTabView!

    convenience init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 540),
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

    // MARK: - General Tab

    private func createGeneralTab() -> NSTabViewItem {
        let tab = NSTabViewItem(identifier: "general")
        tab.label = "General"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        var y: CGFloat = 360

        for (title, isOn) in [
            ("Remember session for next launch", true),
            ("Exit when last tab is closed", true),
            ("Double-click tab to close", false),
        ] {
            let cb = NSButton(checkboxWithTitle: title, target: nil, action: nil)
            cb.state = isOn ? .on : .off
            cb.frame = NSRect(x: 20, y: y, width: 440, height: 20)
            view.addSubview(cb)
            y -= 28
        }

        tab.view = view
        return tab
    }

    // MARK: - Editor Tab

    private func createEditorTab() -> NSTabViewItem {
        let tab = NSTabViewItem(identifier: "editor")
        tab.label = "Editor"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        var y: CGFloat = 360

        let fields: [(String, String)] = [("Tab size:", "4"), ("Large file threshold (KB):", "2000")]
        for (label, value) in fields {
            let l = NSTextField(labelWithString: label)
            l.frame = NSRect(x: 20, y: y, width: 200, height: 20)
            view.addSubview(l)
            let f = NSTextField(frame: NSRect(x: 225, y: y, width: 60, height: 22))
            f.stringValue = value
            view.addSubview(f)
            y -= 32
        }

        for (title, isOn) in [
            ("Use spaces instead of tabs", false),
            ("Word wrap by default", false),
            ("Show line numbers", true),
            ("Enable auto-completion", true),
        ] {
            let cb = NSButton(checkboxWithTitle: title, target: nil, action: nil)
            cb.state = isOn ? .on : .off
            cb.frame = NSRect(x: 20, y: y, width: 440, height: 20)
            view.addSubview(cb)
            y -= 28
        }

        tab.view = view
        return tab
    }

    // MARK: - Appearance Tab

    private var editorFontLabel: NSTextField!
    private var uiFontLabel: NSTextField!
    private var fgColorWell: NSColorWell!
    private var bgColorWell: NSColorWell!
    private var themePopup: NSPopUpButton!
    private var appearanceStylePopup: NSPopUpButton!
    private var transparencySlider: NSSlider!
    private var transparencyValueLabel: NSTextField!

    private func createAppearanceTab() -> NSTabViewItem {
        let tab = NSTabViewItem(identifier: "appearance")
        tab.label = "Appearance"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 480))
        var y: CGFloat = 445

        // Theme selector
        let themeLabel = NSTextField(labelWithString: "Theme:")
        themeLabel.frame = NSRect(x: 20, y: y, width: 80, height: 20)
        view.addSubview(themeLabel)

        themePopup = NSPopUpButton(frame: NSRect(x: 100, y: y - 2, width: 200, height: 24))
        for theme in ThemeManager.builtInThemes {
            themePopup.addItem(withTitle: theme.name)
        }
        if let idx = ThemeManager.builtInThemes.firstIndex(where: { $0.name == ThemeManager.shared.currentTheme.name }) {
            themePopup.selectItem(at: idx)
        }
        themePopup.target = self
        themePopup.action = #selector(themeSelected(_:))
        view.addSubview(themePopup)
        y -= 40

        let sep1 = NSBox(frame: NSRect(x: 20, y: y, width: 460, height: 1))
        sep1.boxType = .separator
        view.addSubview(sep1)
        y -= 16

        // Monospaced (editor) font
        let editorFontTitle = NSTextField(labelWithString: "Editor font:")
        editorFontTitle.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(editorFontTitle)

        editorFontLabel = NSTextField(labelWithString: describeFont(ThemeManager.shared.currentTheme.editorFont))
        editorFontLabel.frame = NSRect(x: 125, y: y, width: 220, height: 20)
        view.addSubview(editorFontLabel)

        let editorFontBtn = NSButton(title: "Choose…", target: self, action: #selector(chooseEditorFont))
        editorFontBtn.frame = NSRect(x: 355, y: y - 2, width: 80, height: 24)
        view.addSubview(editorFontBtn)
        y -= 36

        // UI font
        let uiFontTitle = NSTextField(labelWithString: "UI font:")
        uiFontTitle.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(uiFontTitle)

        uiFontLabel = NSTextField(labelWithString: describeFont(ThemeManager.shared.currentTheme.uiFont))
        uiFontLabel.frame = NSRect(x: 125, y: y, width: 220, height: 20)
        view.addSubview(uiFontLabel)

        let uiFontBtn = NSButton(title: "Choose…", target: self, action: #selector(chooseUIFont))
        uiFontBtn.frame = NSRect(x: 355, y: y - 2, width: 80, height: 24)
        view.addSubview(uiFontBtn)
        y -= 36

        let sep2 = NSBox(frame: NSRect(x: 20, y: y, width: 460, height: 1))
        sep2.boxType = .separator
        view.addSubview(sep2)
        y -= 20

        // Font color
        let fgLabel = NSTextField(labelWithString: "Text color:")
        fgLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(fgLabel)

        fgColorWell = NSColorWell(frame: NSRect(x: 125, y: y - 2, width: 44, height: 24))
        fgColorWell.color = ThemeManager.shared.currentTheme.foreground
        fgColorWell.target = self
        fgColorWell.action = #selector(foregroundColorChanged(_:))
        view.addSubview(fgColorWell)
        y -= 36

        // Background color
        let bgLabel = NSTextField(labelWithString: "Background:")
        bgLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(bgLabel)

        bgColorWell = NSColorWell(frame: NSRect(x: 125, y: y - 2, width: 44, height: 24))
        bgColorWell.color = ThemeManager.shared.currentTheme.background
        bgColorWell.target = self
        bgColorWell.action = #selector(backgroundColorChanged(_:))
        view.addSubview(bgColorWell)
        y -= 40

        let sepA = NSBox(frame: NSRect(x: 20, y: y, width: 460, height: 1))
        sepA.boxType = .separator
        view.addSubview(sepA)
        y -= 20

        // Window style (Standard / Transparency)
        let styleLabel = NSTextField(labelWithString: "Window style:")
        styleLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(styleLabel)

        appearanceStylePopup = NSPopUpButton(frame: NSRect(x: 125, y: y - 2, width: 200, height: 24))
        for style in AppearanceStyle.allCases {
            appearanceStylePopup.addItem(withTitle: style.displayName)
        }
        if let idx = AppearanceStyle.allCases.firstIndex(of: EditorSettings.appearanceStyle) {
            appearanceStylePopup.selectItem(at: idx)
        }
        appearanceStylePopup.target = self
        appearanceStylePopup.action = #selector(appearanceStyleSelected(_:))
        view.addSubview(appearanceStylePopup)
        y -= 32

        // Window opacity slider (only meaningful in Transparency mode but
        // editable anytime so users can preview before switching).
        let opacityLabel = NSTextField(labelWithString: "Window opacity:")
        opacityLabel.frame = NSRect(x: 20, y: y, width: 110, height: 20)
        view.addSubview(opacityLabel)

        transparencySlider = NSSlider(value: Double(EditorSettings.transparencyAlpha),
                                       minValue: Double(EditorSettings.minTransparencyAlpha),
                                       maxValue: Double(EditorSettings.maxTransparencyAlpha),
                                       target: self,
                                       action: #selector(transparencySliderChanged(_:)))
        transparencySlider.frame = NSRect(x: 130, y: y - 2, width: 240, height: 24)
        transparencySlider.isContinuous = true
        view.addSubview(transparencySlider)

        transparencyValueLabel = NSTextField(labelWithString: percentString(EditorSettings.transparencyAlpha))
        transparencyValueLabel.frame = NSRect(x: 380, y: y, width: 50, height: 20)
        transparencyValueLabel.alignment = .right
        view.addSubview(transparencyValueLabel)
        y -= 36

        // Preview
        let sep3 = NSBox(frame: NSRect(x: 20, y: y, width: 460, height: 1))
        sep3.boxType = .separator
        view.addSubview(sep3)
        y -= 8

        let previewLabel = NSTextField(labelWithString: "Preview:")
        previewLabel.frame = NSRect(x: 20, y: y, width: 60, height: 16)
        previewLabel.font = NSFont.boldSystemFont(ofSize: 11)
        view.addSubview(previewLabel)
        y -= 6

        let previewBg = NSView(frame: NSRect(x: 20, y: y - 80, width: 460, height: 86))
        previewBg.wantsLayer = true
        previewBg.layer?.backgroundColor = ThemeManager.shared.currentTheme.background.cgColor
        previewBg.layer?.cornerRadius = 6
        previewBg.layer?.borderColor = NSColor.separatorColor.cgColor
        previewBg.layer?.borderWidth = 0.5
        previewBg.identifier = NSUserInterfaceItemIdentifier("previewBg")
        view.addSubview(previewBg)

        let previewText = NSTextField(labelWithString:
            "func greet(name: String) -> String {\n    return \"Hello, \\(name)!\"\n}\n// This is a preview")
        previewText.font = ThemeManager.shared.currentTheme.editorFont
        previewText.textColor = ThemeManager.shared.currentTheme.foreground
        previewText.frame = NSRect(x: 8, y: 6, width: 444, height: 74)
        previewText.maximumNumberOfLines = 5
        previewText.identifier = NSUserInterfaceItemIdentifier("previewText")
        previewBg.addSubview(previewText)

        tab.view = view
        return tab
    }

    // MARK: - Actions

    @objc private func themeSelected(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx >= 0, idx < ThemeManager.builtInThemes.count else { return }
        ThemeManager.shared.currentTheme = ThemeManager.builtInThemes[idx]
        updateAppearanceControls()
    }

    @objc private func chooseEditorFont() {
        let fm = NSFontManager.shared
        fm.target = self
        fm.setSelectedFont(ThemeManager.shared.currentTheme.editorFont, isMultiple: false)
        fm.action = #selector(editorFontChanged(_:))
        fm.orderFrontFontPanel(self)
    }

    @objc private func chooseUIFont() {
        let fm = NSFontManager.shared
        fm.target = self
        fm.setSelectedFont(ThemeManager.shared.currentTheme.uiFont, isMultiple: false)
        fm.action = #selector(uiFontChanged(_:))
        fm.orderFrontFontPanel(self)
    }

    @objc private func editorFontChanged(_ sender: NSFontManager) {
        let newFont = sender.convert(ThemeManager.shared.currentTheme.editorFont)
        ThemeManager.shared.currentTheme.editorFont = newFont
        editorFontLabel?.stringValue = describeFont(newFont)
        ThemeManager.shared.applyTheme()
        updatePreview()
    }

    @objc private func uiFontChanged(_ sender: NSFontManager) {
        let newFont = sender.convert(ThemeManager.shared.currentTheme.uiFont)
        ThemeManager.shared.currentTheme.uiFont = newFont
        uiFontLabel?.stringValue = describeFont(newFont)
        ThemeManager.shared.applyTheme()
    }

    @objc private func foregroundColorChanged(_ sender: NSColorWell) {
        ThemeManager.shared.currentTheme.foreground = sender.color
        ThemeManager.shared.applyTheme()
        updatePreview()
    }

    @objc private func backgroundColorChanged(_ sender: NSColorWell) {
        ThemeManager.shared.currentTheme.background = sender.color
        ThemeManager.shared.applyTheme()
        updatePreview()
    }

    @objc private func appearanceStyleSelected(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        let all = AppearanceStyle.allCases
        guard idx >= 0, idx < all.count else { return }
        EditorSettings.appearanceStyle = all[idx]
        NotificationCenter.default.post(name: .nmmAppearanceDidChange, object: nil)
    }

    @objc private func transparencySliderChanged(_ sender: NSSlider) {
        let alpha = CGFloat(sender.doubleValue)
        EditorSettings.transparencyAlpha = alpha
        transparencyValueLabel?.stringValue = percentString(alpha)
        NotificationCenter.default.post(name: .nmmAppearanceDidChange, object: nil)
    }

    private func percentString(_ alpha: CGFloat) -> String {
        return "\(Int(round(alpha * 100)))%"
    }

    private func updateAppearanceControls() {
        let theme = ThemeManager.shared.currentTheme
        editorFontLabel?.stringValue = describeFont(theme.editorFont)
        uiFontLabel?.stringValue = describeFont(theme.uiFont)
        fgColorWell?.color = theme.foreground
        bgColorWell?.color = theme.background
        updatePreview()
    }

    private func updatePreview() {
        guard let tab = tabView?.tabViewItem(at: 2),
              let view = tab.view else { return }
        let theme = ThemeManager.shared.currentTheme
        if let bg = view.findView(id: "previewBg") {
            bg.layer?.backgroundColor = theme.background.cgColor
            if let txt = bg.findView(id: "previewText") as? NSTextField {
                txt.textColor = theme.foreground
                txt.font = theme.editorFont
            }
        }
    }

    private func describeFont(_ font: NSFont) -> String {
        return "\(font.displayName ?? font.fontName), \(Int(font.pointSize))pt"
    }

    func showAndFocus() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

private extension NSView {
    func findView(id: String) -> NSView? {
        if identifier?.rawValue == id { return self }
        for sub in subviews {
            if let found = sub.findView(id: id) { return found }
        }
        return nil
    }
}
