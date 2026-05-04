import AppKit

/// A single editor view wrapping NSTextView (placeholder for Scintilla).
/// This will be replaced with ScintillaView once Scintilla Cocoa is integrated.
class EditorView: NSView {

    private(set) var textView: NSTextView!
    private var scrollView: NSScrollView!
    private let syntaxHighlighter = SyntaxHighlighter()

    weak var delegate: EditorViewDelegate?

    var language: String {
        get { syntaxHighlighter.language }
        set { syntaxHighlighter.language = newValue }
    }

    var text: String {
        get { textView.string }
        set { textView.string = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        scrollView = NSScrollView(frame: bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false

        // Editor appearance
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .textColor

        // Allow horizontal scrolling
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                   height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView

        // Attach syntax highlighter
        textView.textStorage?.delegate = syntaxHighlighter

        // Line numbers (via ruler) — must be after documentView is set
        scrollView.rulersVisible = true
        scrollView.hasVerticalRuler = true
        let rulerView = LineNumberRulerView(scrollView: scrollView, textView: textView)
        scrollView.verticalRulerView = rulerView

        addSubview(scrollView)

        textView.delegate = self
    }
}

// MARK: - NSTextViewDelegate

extension EditorView: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        delegate?.editorViewDidChange(self)
        // Update line number ruler
        if let ruler = (superview?.superview as? NSScrollView)?.verticalRulerView {
            ruler.needsDisplay = true
        }
    }
}

protocol EditorViewDelegate: AnyObject {
    func editorViewDidChange(_ editorView: EditorView)
}

// MARK: - Line Number Ruler View

class LineNumberRulerView: NSRulerView {

    private weak var textView: NSTextView?

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 40

        NotificationCenter.default.addObserver(
            self, selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification, object: textView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let visibleRect = scrollView?.contentView.bounds ?? .zero
        let visibleGlyphRange = layoutManager.glyphRange(
            forBoundingRect: visibleRect, in: textContainer
        )
        let visibleCharRange = layoutManager.characterRange(
            forGlyphRange: visibleGlyphRange, actualGlyphRange: nil
        )

        let content = textView.string as NSString
        var lineNumber = 1

        // Count lines before visible range
        content.enumerateSubstrings(
            in: NSRange(location: 0, length: visibleCharRange.location),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in
            lineNumber += 1
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        // Draw line numbers for visible lines
        content.enumerateSubstrings(
            in: visibleCharRange,
            options: [.byLines, .substringNotRequired]
        ) { _, substringRange, _, _ in
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: substringRange, actualCharacterRange: nil
            )
            let lineRect = layoutManager.boundingRect(
                forGlyphRange: glyphRange, in: textContainer
            )

            let y = lineRect.minY - visibleRect.minY
            let numStr = "\(lineNumber)" as NSString
            let size = numStr.size(withAttributes: attrs)
            let x = self.ruleThickness - size.width - 5
            numStr.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            lineNumber += 1
        }
    }
}
