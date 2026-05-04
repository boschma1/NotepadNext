import AppKit

/// Provides text editing operations that extend the basic NSTextView capabilities.
/// These mirror Notepad++ Edit menu operations.
class EditorCommands {

    private(set) weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
    }

    // MARK: - Line Operations

    func duplicateLine() {
        guard let tv = textView else { return }
        let range = currentLineRange()
        let line = (tv.string as NSString).substring(with: range)
        let insertion = line.hasSuffix("\n") ? line : "\n" + line
        let insertionPoint = range.location + range.length
        tv.insertText(insertion, replacementRange: NSRange(location: insertionPoint, length: 0))
    }

    func deleteLine() {
        guard let tv = textView else { return }
        let range = currentLineRange()
        tv.insertText("", replacementRange: range)
    }

    func moveLineUp() {
        guard let tv = textView else { return }
        let lineRange = currentLineRange()
        guard lineRange.location > 0 else { return }

        let str = tv.string as NSString
        let line = str.substring(with: lineRange)

        // Find previous line
        let prevLineEnd = lineRange.location - 1
        let prevLineStart = str.lineRange(for: NSRange(location: prevLineEnd, length: 0)).location
        let prevLineRange = NSRange(location: prevLineStart, length: lineRange.location - prevLineStart)
        let prevLine = str.substring(with: prevLineRange)

        // Swap
        let combinedRange = NSRange(location: prevLineRange.location,
                                    length: prevLineRange.length + lineRange.length)
        let newText = line.hasSuffix("\n") ? line + prevLine : prevLine + line
        tv.insertText(newText, replacementRange: combinedRange)

        // Restore cursor to the moved line
        let newCursorPos = prevLineRange.location + (line.hasSuffix("\n") ? 0 : prevLine.count)
        tv.setSelectedRange(NSRange(location: newCursorPos, length: 0))
    }

    func moveLineDown() {
        guard let tv = textView else { return }
        let str = tv.string as NSString
        let lineRange = currentLineRange()
        let lineEnd = lineRange.location + lineRange.length
        guard lineEnd < str.length else { return }

        let line = str.substring(with: lineRange)

        // Find next line
        let nextLineRange = str.lineRange(for: NSRange(location: lineEnd, length: 0))
        let nextLine = str.substring(with: nextLineRange)

        // Swap
        let combinedRange = NSRange(location: lineRange.location,
                                    length: lineRange.length + nextLineRange.length)
        let newText = nextLine.hasSuffix("\n") ? nextLine + line : line + nextLine
        tv.insertText(newText, replacementRange: combinedRange)

        // Restore cursor
        let newCursorPos = lineRange.location + nextLineRange.length
        tv.setSelectedRange(NSRange(location: newCursorPos, length: 0))
    }

    // MARK: - Case Conversion

    func convertToUpperCase() {
        transformSelectedText { $0.uppercased() }
    }

    func convertToLowerCase() {
        transformSelectedText { $0.lowercased() }
    }

    func convertToTitleCase() {
        transformSelectedText { $0.capitalized }
    }

    // MARK: - Comment Toggle

    func toggleLineComment(prefix: String = "//") {
        guard let tv = textView else { return }
        let str = tv.string as NSString
        let lineRange = currentLineRange()
        let line = str.substring(with: lineRange)
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix(prefix) {
            // Uncomment: remove first occurrence of prefix
            if let prefixRange = line.range(of: prefix) {
                let nsRange = NSRange(prefixRange, in: line)
                let absoluteRange = NSRange(location: lineRange.location + nsRange.location,
                                             length: nsRange.length)
                // Also remove one trailing space if present
                let afterPrefix = lineRange.location + nsRange.location + nsRange.length
                if afterPrefix < str.length && str.character(at: afterPrefix) == Character(" ").asciiValue! {
                    tv.insertText("", replacementRange: NSRange(location: absoluteRange.location,
                                                                 length: absoluteRange.length + 1))
                } else {
                    tv.insertText("", replacementRange: absoluteRange)
                }
            }
        } else {
            // Comment: find indentation and insert prefix
            let indent = line.prefix(while: { $0 == " " || $0 == "\t" })
            let insertPos = lineRange.location + indent.count
            tv.insertText(prefix + " ", replacementRange: NSRange(location: insertPos, length: 0))
        }
    }

    // MARK: - Indentation

    func increaseIndent() {
        guard let tv = textView else { return }
        let lineRange = currentLineRange()
        tv.insertText("\t", replacementRange: NSRange(location: lineRange.location, length: 0))
    }

    func decreaseIndent() {
        guard let tv = textView else { return }
        let str = tv.string as NSString
        let lineRange = currentLineRange()
        if lineRange.length > 0 {
            let firstChar = str.character(at: lineRange.location)
            if firstChar == Character("\t").asciiValue! {
                tv.insertText("", replacementRange: NSRange(location: lineRange.location, length: 1))
            } else if firstChar == Character(" ").asciiValue! {
                // Remove up to 4 spaces
                var count = 0
                while count < 4 && lineRange.location + count < str.length &&
                        str.character(at: lineRange.location + count) == Character(" ").asciiValue! {
                    count += 1
                }
                if count > 0 {
                    tv.insertText("", replacementRange: NSRange(location: lineRange.location, length: count))
                }
            }
        }
    }

    // MARK: - Whitespace Operations

    func trimTrailingWhitespace() {
        guard let tv = textView else { return }
        let lines = tv.string.components(separatedBy: "\n")
        let trimmed = lines.map { $0.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) }
        let newText = trimmed.joined(separator: "\n")
        if newText != tv.string {
            let cursorPos = tv.selectedRange().location
            tv.string = newText
            let newPos = min(cursorPos, newText.count)
            tv.setSelectedRange(NSRange(location: newPos, length: 0))
        }
    }

    func convertTabsToSpaces(tabSize: Int = 4) {
        guard let tv = textView else { return }
        let spaces = String(repeating: " ", count: tabSize)
        let newText = tv.string.replacingOccurrences(of: "\t", with: spaces)
        if newText != tv.string {
            tv.string = newText
        }
    }

    func convertSpacesToTabs(tabSize: Int = 4) {
        guard let tv = textView else { return }
        let spaces = String(repeating: " ", count: tabSize)
        let newText = tv.string.replacingOccurrences(of: spaces, with: "\t")
        if newText != tv.string {
            tv.string = newText
        }
    }

    // MARK: - Helpers

    private func currentLineRange() -> NSRange {
        guard let tv = textView else { return NSRange(location: 0, length: 0) }
        let selectedRange = tv.selectedRange()
        return (tv.string as NSString).lineRange(for: selectedRange)
    }

    private func transformSelectedText(_ transform: (String) -> String) {
        guard let tv = textView else { return }
        let range = tv.selectedRange()
        guard range.length > 0 else { return }
        let selected = (tv.string as NSString).substring(with: range)
        let transformed = transform(selected)
        tv.insertText(transformed, replacementRange: range)
    }
}
