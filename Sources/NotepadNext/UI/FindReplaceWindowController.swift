import AppKit

/// Find & Replace panel that replicates core Notepad++ search functionality.
class FindReplaceWindowController: NSWindowController {

    private var findField: NSTextField!
    private var replaceField: NSTextField!
    private var matchCaseCheckbox: NSButton!
    private var wholeWordCheckbox: NSButton!
    private var regexCheckbox: NSButton!
    private var wrapAroundCheckbox: NSButton!
    private var statusLabel: NSTextField!

    private weak var targetTextView: NSTextView?

    convenience init(textView: NSTextView) {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 220),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = "Find & Replace"
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.level = .floating

        self.init(window: window)
        self.targetTextView = textView
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let findLabel = NSTextField(labelWithString: "Find:")
        findField = NSTextField()
        findField.placeholderString = "Search text"

        let replaceLabel = NSTextField(labelWithString: "Replace:")
        replaceField = NSTextField()
        replaceField.placeholderString = "Replacement text"

        matchCaseCheckbox = NSButton(checkboxWithTitle: "Match case", target: nil, action: nil)
        wholeWordCheckbox = NSButton(checkboxWithTitle: "Whole word", target: nil, action: nil)
        regexCheckbox = NSButton(checkboxWithTitle: "Regex", target: nil, action: nil)
        wrapAroundCheckbox = NSButton(checkboxWithTitle: "Wrap around", target: nil, action: nil)
        wrapAroundCheckbox.state = .on

        let findNextBtn = NSButton(title: "Find Next", target: self, action: #selector(findNext))
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

    @objc private func replaceCurrent() {
        guard let tv = targetTextView else { return }
        let selectedRange = tv.selectedRange()
        guard selectedRange.length > 0 else {
            search(forward: true)
            return
        }

        let replacement = replaceField.stringValue
        tv.insertText(replacement, replacementRange: selectedRange)
        search(forward: true)
    }

    @objc private func replaceAll() {
        guard let tv = targetTextView else { return }
        let searchText = findField.stringValue
        guard !searchText.isEmpty else { return }

        let replacement = replaceField.stringValue
        let options = buildSearchOptions()
        let content = tv.string

        var newContent: String
        var count: Int

        if regexCheckbox.state == .on {
            do {
                let regex = try NSRegularExpression(pattern: searchText, options: regexOptions())
                let range = NSRange(location: 0, length: (content as NSString).length)
                let results = regex.matches(in: content, range: range)
                count = results.count
                newContent = regex.stringByReplacingMatches(in: content, range: range, withTemplate: replacement)
            } catch {
                statusLabel.stringValue = "Invalid regex: \(error.localizedDescription)"
                return
            }
        } else {
            count = 0
            newContent = content
            while let range = newContent.range(of: searchText, options: options) {
                newContent.replaceSubrange(range, with: replacement)
                count += 1
            }
        }

        if count > 0 {
            tv.string = newContent
            statusLabel.stringValue = "Replaced \(count) occurrence(s)"
        } else {
            statusLabel.stringValue = "No matches found"
        }
    }

    @objc private func countMatches() {
        guard let tv = targetTextView else { return }
        let searchText = findField.stringValue
        guard !searchText.isEmpty else { return }

        let content = tv.string
        let count: Int

        if regexCheckbox.state == .on {
            do {
                let regex = try NSRegularExpression(pattern: searchText, options: regexOptions())
                let range = NSRange(location: 0, length: (content as NSString).length)
                count = regex.numberOfMatches(in: content, range: range)
            } catch {
                statusLabel.stringValue = "Invalid regex: \(error.localizedDescription)"
                return
            }
        } else {
            let options = buildSearchOptions()
            var c = 0
            var searchRange = content.startIndex..<content.endIndex
            while let range = content.range(of: searchText, options: options, range: searchRange) {
                c += 1
                searchRange = range.upperBound..<content.endIndex
            }
            count = c
        }

        statusLabel.stringValue = "\(count) match(es) found"
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

        if regexCheckbox.state == .on {
            do {
                let regex = try NSRegularExpression(pattern: searchText, options: regexOptions())
                if forward {
                    let searchRange = NSRange(location: startLocation, length: content.length - startLocation)
                    if let match = regex.firstMatch(in: tv.string, range: searchRange) {
                        foundRange = match.range
                    } else if wrapAroundCheckbox.state == .on {
                        let wrapRange = NSRange(location: 0, length: startLocation)
                        if let match = regex.firstMatch(in: tv.string, range: wrapRange) {
                            foundRange = match.range
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
                        }
                    }
                }
            } catch {
                statusLabel.stringValue = "Invalid regex: \(error.localizedDescription)"
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
                }
            }
        }

        if foundRange.location != NSNotFound {
            tv.setSelectedRange(foundRange)
            tv.scrollRangeToVisible(foundRange)
            tv.showFindIndicator(for: foundRange)
            statusLabel.stringValue = ""
        } else {
            statusLabel.stringValue = "Not found"
            NSSound.beep()
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

    // MARK: - Public

    func showAndFocus() {
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(findField)

        // Pre-fill with selection
        if let tv = targetTextView {
            let range = tv.selectedRange()
            if range.length > 0 && range.length < 500 {
                let selected = (tv.string as NSString).substring(with: range)
                findField.stringValue = selected
            }
        }
    }
}
