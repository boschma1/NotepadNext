import AppKit

/// Find & Replace panel that replicates core Notepad++ search functionality.
class FindReplaceWindowController: NSWindowController, NSTextFieldDelegate, NSWindowDelegate {

    private var findField: NSTextField!
    private var replaceField: NSTextField!
    private var matchCaseCheckbox: NSButton!
    private var wholeWordCheckbox: NSButton!
    private var regexCheckbox: NSButton!
    private var wrapAroundCheckbox: NSButton!
    private var statusLabel: NSTextField!
    private var findNextBtn: NSButton!

    private weak var targetTextView: NSTextView?
    private weak var previousResponder: NSResponder?

    convenience init(textView: NSTextView) {
        // Use a normal NSWindow (not NSPanel). NSPanel + utilityWindow leaves
        // the app with no key window after closing, which freezes input.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 220),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Find & Replace"
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        // setFrameAutosaveName restores any previously saved frame; if none
        // exists the origin remains (0,0), so we center for first-ever launch.
        window.setFrameAutosaveName("FindReplacePanel")
        if window.frame.origin == .zero {
            window.center()
        }

        self.init(window: window)
        self.targetTextView = textView
        window.delegate = self
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let findLabel = NSTextField(labelWithString: "Find:")
        findField = NSTextField()
        findField.placeholderString = "Search text"
        findField.target = self
        findField.action = #selector(findFieldEnter)
        findField.delegate = self

        let replaceLabel = NSTextField(labelWithString: "Replace:")
        replaceField = NSTextField()
        replaceField.placeholderString = "Replacement text"
        replaceField.target = self
        replaceField.action = #selector(replaceFieldEnter)
        replaceField.delegate = self

        matchCaseCheckbox = NSButton(checkboxWithTitle: "Match case", target: nil, action: nil)
        wholeWordCheckbox = NSButton(checkboxWithTitle: "Whole word", target: nil, action: nil)
        regexCheckbox = NSButton(checkboxWithTitle: "Regex", target: nil, action: nil)
        wrapAroundCheckbox = NSButton(checkboxWithTitle: "Wrap around", target: nil, action: nil)
        wrapAroundCheckbox.state = .on

        findNextBtn = NSButton(title: "Find Next", target: self, action: #selector(findNext))
        findNextBtn.keyEquivalent = "\r"
        let findPrevBtn = NSButton(title: "Find Previous", target: self, action: #selector(findPrevious))
        let replaceBtn = NSButton(title: "Replace", target: self, action: #selector(replaceCurrent))
        let replaceAllBtn = NSButton(title: "Replace All", target: self, action: #selector(replaceAll))
        let countBtn = NSButton(title: "Count", target: self, action: #selector(countMatches))

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 11)

        // Layout using stack views
        let fieldsGrid = NSGridView(views: [
            [findLabel, findField],
            [replaceLabel, replaceField],
        ])
        fieldsGrid.column(at: 0).width = 60
        fieldsGrid.column(at: 1).width = 360
        fieldsGrid.rowSpacing = 8

        let optionsStack = NSStackView(views: [matchCaseCheckbox, wholeWordCheckbox, regexCheckbox, wrapAroundCheckbox])
        optionsStack.orientation = .horizontal
        optionsStack.spacing = 12

        let buttonsStack = NSStackView(views: [findNextBtn, findPrevBtn, replaceBtn, replaceAllBtn, countBtn])
        buttonsStack.orientation = .horizontal
        buttonsStack.spacing = 8

        let mainStack = NSStackView(views: [fieldsGrid, optionsStack, buttonsStack, statusLabel])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func findNext() {
        search(forward: true)
    }

    @objc private func findPrevious() {
        search(forward: false)
    }

    @objc private func findFieldEnter() {
        // Triggered by Enter in find field; honors Shift via current event.
        let backward = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
        search(forward: !backward)
    }

    @objc private func replaceFieldEnter() {
        replaceCurrent()
    }

    @objc private func replaceCurrent() {
        guard let tv = targetTextView else { return }
        let selectedRange = tv.selectedRange()
        guard selectedRange.length > 0 else {
            search(forward: true)
            return
        }

        let replacement = replaceField.stringValue
        if tv.shouldChangeText(in: selectedRange, replacementString: replacement) {
            tv.textStorage?.replaceCharacters(in: selectedRange, with: replacement)
            tv.didChangeText()
        }
        search(forward: true)
    }

    @objc private func replaceAll() {
        guard let tv = targetTextView else { return }
        let searchText = findField.stringValue
        guard !searchText.isEmpty else { return }

        let replacement = replaceField.stringValue
        let mutable = NSMutableString(string: tv.string)
        let fullRange = NSRange(location: 0, length: mutable.length)
        var count: Int

        if regexCheckbox.state == .on {
            do {
                let regex = try NSRegularExpression(pattern: searchText, options: regexOptions())
                count = regex.replaceMatches(in: mutable, range: fullRange, withTemplate: replacement)
            } catch {
                statusLabel.stringValue = "Invalid regex: \(error.localizedDescription)"
                return
            }
        } else {
            if wholeWordCheckbox.state == .on {
                // Whole word in plain mode goes via regex for word boundaries.
                let escaped = NSRegularExpression.escapedPattern(for: searchText)
                do {
                    let regex = try NSRegularExpression(pattern: "\\b\(escaped)\\b",
                                                        options: regexOptions())
                    count = regex.replaceMatches(in: mutable, range: fullRange, withTemplate: replacement)
                } catch {
                    statusLabel.stringValue = "Invalid pattern: \(error.localizedDescription)"
                    return
                }
            } else {
                let opts = buildNSStringOptions(forward: true)
                count = mutable.replaceOccurrences(of: searchText, with: replacement,
                                                   options: opts, range: fullRange)
            }
        }

        if count > 0 {
            let newContent = mutable as String
            let storageRange = NSRange(location: 0, length: (tv.string as NSString).length)
            if tv.shouldChangeText(in: storageRange, replacementString: newContent) {
                tv.textStorage?.replaceCharacters(in: storageRange, with: newContent)
                tv.didChangeText()
            }
            statusLabel.stringValue = "Replaced \(count) occurrence\(count == 1 ? "" : "s")"
        } else {
            statusLabel.stringValue = "No matches found"
        }
    }

    @objc private func countMatches() {
        guard let tv = targetTextView else { return }
        let searchText = findField.stringValue
        guard !searchText.isEmpty else { return }
        let count = countAllMatches(in: tv.string, pattern: searchText)
        statusLabel.stringValue = count.map { "\($0) match\($0 == 1 ? "" : "es") found" }
            ?? "Invalid pattern"
    }

    // MARK: - Search logic

    private func search(forward: Bool) {
        guard let tv = targetTextView else { return }
        let searchText = findField.stringValue
        guard !searchText.isEmpty else { return }

        let content = tv.string as NSString
        let currentSelection = tv.selectedRange()

        let startLocation: Int
        if forward {
            startLocation = currentSelection.location + currentSelection.length
        } else {
            startLocation = max(0, currentSelection.location - 1)
        }

        var foundRange: NSRange = NSRange(location: NSNotFound, length: 0)
        var wrapped = false

        if regexCheckbox.state == .on || wholeWordCheckbox.state == .on {
            let pattern: String
            if regexCheckbox.state == .on {
                pattern = searchText
            } else {
                pattern = "\\b\(NSRegularExpression.escapedPattern(for: searchText))\\b"
            }
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: regexOptions())
                if forward {
                    let searchRange = NSRange(location: startLocation, length: content.length - startLocation)
                    if let match = regex.firstMatch(in: tv.string, range: searchRange) {
                        foundRange = match.range
                    } else if wrapAroundCheckbox.state == .on {
                        let wrapRange = NSRange(location: 0, length: startLocation)
                        if let match = regex.firstMatch(in: tv.string, range: wrapRange) {
                            foundRange = match.range
                            wrapped = true
                        }
                    }
                } else {
                    let searchRange = NSRange(location: 0, length: startLocation)
                    let matches = regex.matches(in: tv.string, range: searchRange)
                    if let last = matches.last {
                        foundRange = last.range
                    } else if wrapAroundCheckbox.state == .on {
                        let wrapRange = NSRange(location: startLocation, length: content.length - startLocation)
                        let matches = regex.matches(in: tv.string, range: wrapRange)
                        if let last = matches.last {
                            foundRange = last.range
                            wrapped = true
                        }
                    }
                }
            } catch {
                statusLabel.stringValue = "Invalid pattern: \(error.localizedDescription)"
                return
            }
        } else {
            let nsOptions = buildNSStringOptions(forward: forward)
            if forward {
                let searchRange = NSRange(location: startLocation, length: content.length - startLocation)
                foundRange = content.range(of: searchText, options: nsOptions, range: searchRange)
                if foundRange.location == NSNotFound && wrapAroundCheckbox.state == .on {
                    foundRange = content.range(of: searchText, options: nsOptions,
                                               range: NSRange(location: 0, length: startLocation))
                    if foundRange.location != NSNotFound { wrapped = true }
                }
            } else {
                let searchRange = NSRange(location: 0, length: startLocation + 1)
                foundRange = content.range(of: searchText, options: nsOptions, range: searchRange)
                if foundRange.location == NSNotFound && wrapAroundCheckbox.state == .on {
                    let wrapRange = NSRange(location: startLocation, length: content.length - startLocation)
                    var wrapOptions = nsOptionsWithoutDirection()
                    wrapOptions.insert(.backwards)
                    foundRange = content.range(of: searchText, options: wrapOptions,
                                               range: wrapRange)
                    if foundRange.location != NSNotFound { wrapped = true }
                }
            }
        }

        if foundRange.location != NSNotFound {
            tv.setSelectedRange(foundRange)
            tv.scrollRangeToVisible(foundRange)
            tv.showFindIndicator(for: foundRange)
            updateMatchStatus(in: tv.string, currentMatch: foundRange, wrapped: wrapped)
        } else {
            statusLabel.stringValue = "Not found"
            NSSound.beep()
        }
    }

    private func updateMatchStatus(in content: String, currentMatch: NSRange, wrapped: Bool) {
        let suffix = wrapped ? " (wrapped)" : ""
        let total = countAllMatches(in: content, pattern: findField.stringValue) ?? 0
        if total > 0 {
            // Find 1-based position of currentMatch.
            var position = 1
            enumerateAllMatches(in: content, pattern: findField.stringValue) { range, stop in
                if range.location == currentMatch.location { stop = true }
                else { position += 1 }
            }
            statusLabel.stringValue = "Match \(position) of \(total)\(suffix)"
        } else {
            statusLabel.stringValue = "1 match\(suffix)"
        }
    }

    private func countAllMatches(in content: String, pattern: String) -> Int? {
        guard !pattern.isEmpty else { return 0 }
        if regexCheckbox.state == .on || wholeWordCheckbox.state == .on {
            let regexPattern: String
            if regexCheckbox.state == .on {
                regexPattern = pattern
            } else {
                regexPattern = "\\b\(NSRegularExpression.escapedPattern(for: pattern))\\b"
            }
            do {
                let regex = try NSRegularExpression(pattern: regexPattern, options: regexOptions())
                let range = NSRange(location: 0, length: (content as NSString).length)
                return regex.numberOfMatches(in: content, range: range)
            } catch {
                return nil
            }
        }
        let options = buildSearchOptions()
        var c = 0
        var searchRange = content.startIndex..<content.endIndex
        while let range = content.range(of: pattern, options: options, range: searchRange) {
            c += 1
            searchRange = range.upperBound..<content.endIndex
        }
        return c
    }

    private func enumerateAllMatches(in content: String, pattern: String,
                                     _ body: (NSRange, inout Bool) -> Void) {
        guard !pattern.isEmpty else { return }
        var stop = false
        if regexCheckbox.state == .on || wholeWordCheckbox.state == .on {
            let regexPattern: String
            if regexCheckbox.state == .on {
                regexPattern = pattern
            } else {
                regexPattern = "\\b\(NSRegularExpression.escapedPattern(for: pattern))\\b"
            }
            guard let regex = try? NSRegularExpression(pattern: regexPattern, options: regexOptions())
            else { return }
            let range = NSRange(location: 0, length: (content as NSString).length)
            regex.enumerateMatches(in: content, range: range) { match, _, ptr in
                guard let m = match else { return }
                body(m.range, &stop)
                if stop { ptr.pointee = true }
            }
            return
        }
        let options = buildNSStringOptions(forward: true)
        let ns = content as NSString
        var location = 0
        while location < ns.length {
            let range = ns.range(of: pattern, options: options,
                                 range: NSRange(location: location, length: ns.length - location))
            if range.location == NSNotFound { return }
            body(range, &stop)
            if stop { return }
            location = range.location + max(range.length, 1)
        }
    }

    // MARK: - Option builders

    private func buildSearchOptions() -> String.CompareOptions {
        var options: String.CompareOptions = []
        if matchCaseCheckbox.state == .off { options.insert(.caseInsensitive) }
        return options
    }

    private func buildNSStringOptions(forward: Bool) -> NSString.CompareOptions {
        var options: NSString.CompareOptions = []
        if matchCaseCheckbox.state == .off { options.insert(.caseInsensitive) }
        if !forward { options.insert(.backwards) }
        return options
    }

    private func nsOptionsWithoutDirection() -> NSString.CompareOptions {
        var options: NSString.CompareOptions = []
        if matchCaseCheckbox.state == .off { options.insert(.caseInsensitive) }
        return options
    }

    private func regexOptions() -> NSRegularExpression.Options {
        var options: NSRegularExpression.Options = []
        if matchCaseCheckbox.state == .off { options.insert(.caseInsensitive) }
        return options
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView,
                 doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.cancelOperation(_:)):
            closePanel()
            return true
        case #selector(NSResponder.insertNewline(_:)):
            // Default handled by target/action; let NSTextField fire normally.
            return false
        case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
            // Option+Return — also trigger find.
            search(forward: true)
            return true
        default:
            return false
        }
    }

    private func closePanel() {
        window?.performClose(nil)
    }

    /// Forces the main editor window back to the foreground and re-installs the
    /// text view as first responder. AppKit does not always do this reliably
    /// when a floating utility window closes while it is the key window, which
    /// can leave the app with no key window — the editor then stops accepting
    /// keystrokes until the user clicks somewhere. Activate the app explicitly
    /// and make the editor key again on the next runloop tick.
    private func restoreEditorFocus() {
        guard let tv = targetTextView, let mainWindow = tv.window else { return }
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            mainWindow.makeKeyAndOrderFront(nil)
            mainWindow.makeFirstResponder(tv)
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        restoreEditorFocus()
    }

    func windowDidResignKey(_ notification: Notification) {
        // If the panel resigns key while still on screen (e.g. user clicked
        // back into the editor) we don't need to force focus. But if it is
        // also being closed, windowWillClose will handle it.
    }

    // MARK: - Public

    func showAndFocus() {
        guard let window = window else { return }
        previousResponder = NSApp.keyWindow?.firstResponder
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(findField)

        // Pre-fill with selection if there is one; otherwise keep prior text.
        if let tv = targetTextView {
            let range = tv.selectedRange()
            if range.length > 0 && range.length < 500 {
                let selected = (tv.string as NSString).substring(with: range)
                findField.stringValue = selected
            }
        }
        // Select-all in find field so the user can immediately type to replace.
        findField.currentEditor()?.selectAll(nil)
    }
}
