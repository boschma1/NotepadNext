import AppKit

/// NSTextView subclass with plain text paste/copy and Cmd+Click URL opening.
class PlainTextView: NSTextView {

    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func pasteAsRichText(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func copy(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        let selectedText = (string as NSString).substring(with: range)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(selectedText, forType: .string)
    }

    override func cut(_ sender: Any?) {
        copy(sender)
        deleteBackward(sender)
    }

    // MARK: - Cmd+Click to open URLs

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            let point = convert(event.locationInWindow, from: nil)
            let charIndex = characterIndexForInsertion(at: point)
            if let url = detectURL(at: charIndex) {
                NSWorkspace.shared.open(url)
                return
            }
        }
        super.mouseDown(with: event)
    }

    private func detectURL(at charIndex: Int) -> URL? {
        let text = string as NSString
        guard charIndex >= 0, charIndex < text.length else { return nil }

        // Get the line containing the click
        let lineRange = text.lineRange(for: NSRange(location: charIndex, length: 0))
        let line = text.substring(with: lineRange)

        // Find URLs in the line
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: line, range: NSRange(location: 0, length: (line as NSString).length)) ?? []

        for match in matches {
            let absoluteRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
            if NSLocationInRange(charIndex, absoluteRange), let url = match.url {
                return url
            }
        }
        return nil
    }
}
