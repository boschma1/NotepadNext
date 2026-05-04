import AppKit

protocol EditorViewDelegate: AnyObject {
    func editorViewDidChange(_ editorView: EditorView)
}

/// Manages a text editor composed of an NSScrollView + NSTextView,
/// added directly to a parent view (no extra wrapper NSView).
class EditorView: NSObject, NSTextViewDelegate {

    private(set) var textView: NSTextView!
    private(set) var scrollView: NSScrollView!
    private let syntaxHighlighter = SyntaxHighlighter()

    weak var delegate: EditorViewDelegate?

    var language: String {
        get { syntaxHighlighter.language }
        set {
            syntaxHighlighter.language = newValue
            rehighlight()
        }
    }

    var text: String {
        get { textView.string }
        set { textView.string = newValue }
    }

    /// Call this to create and install the editor into a parent view.
    func install(in parentView: NSView, frame: NSRect) {
        scrollView = NSScrollView(frame: frame)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = false

        textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false

        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .textColor

        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView

        // Line number gutter
        scrollView.rulersVisible = true
        scrollView.hasVerticalRuler = true
        scrollView.verticalRulerView = LineNumberGutter(scrollView: scrollView, textView: textView)

        parentView.addSubview(scrollView)
        textView.delegate = self
    }

    func updateFrame(_ frame: NSRect) {
        scrollView.frame = frame
    }

    private func rehighlight() {
        guard let ts = textView.textStorage else { return }
        let range = NSRange(location: 0, length: ts.length)
        let defaultFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        ts.beginEditing()
        ts.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
        ts.addAttribute(.font, value: defaultFont, range: range)

        let rules = SyntaxRules.rules(for: language, theme: syntaxHighlighter.theme)
        for rule in rules {
            guard let regex = rule.regex else { continue }
            regex.enumerateMatches(in: ts.string, range: range) { match, _, _ in
                guard let matchRange = match?.range else { return }
                ts.addAttribute(.foregroundColor, value: rule.color, range: matchRange)
                if let trait = rule.fontTrait {
                    let styled = NSFontManager.shared.convert(defaultFont, toHaveTrait: trait)
                    ts.addAttribute(.font, value: styled, range: matchRange)
                }
            }
        }
        ts.endEditing()
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        delegate?.editorViewDidChange(self)
        rehighlight()
    }
}
