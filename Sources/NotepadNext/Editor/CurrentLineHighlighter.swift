import AppKit

/// Highlights the current line the caret is on.
class CurrentLineHighlighter {

    private weak var textView: NSTextView?
    private let highlightColor = NSColor.controlAccentColor.withAlphaComponent(0.06)

    init(textView: NSTextView) {
        self.textView = textView

        NotificationCenter.default.addObserver(self,
            selector: #selector(selectionChanged),
            name: NSTextView.didChangeSelectionNotification, object: textView)

        highlightCurrentLine()
    }

    @objc private func selectionChanged(_ n: Notification) {
        highlightCurrentLine()
    }

    private func highlightCurrentLine() {
        guard let tv = textView,
              let lm = tv.layoutManager,
              let tc = tv.textContainer else { return }

        // Remove old highlight
        let fullRange = NSRange(location: 0, length: (tv.string as NSString).length)
        lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)

        // Highlight current line
        let sel = tv.selectedRange()
        let lineRange = (tv.string as NSString).lineRange(for: NSRange(location: sel.location, length: 0))
        lm.addTemporaryAttribute(.backgroundColor, value: highlightColor, forCharacterRange: lineRange)
    }
}
