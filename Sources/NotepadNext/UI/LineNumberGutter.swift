import AppKit

/// Line number gutter drawn as an NSRulerView, using frame-based layout.
class LineNumberGutter: NSRulerView {

    private weak var editorTextView: NSTextView?
    private let gutterWidth: CGFloat = 44

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.editorTextView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = gutterWidth

        NotificationCenter.default.addObserver(self,
            selector: #selector(textChanged), name: NSText.didChangeNotification, object: textView)
        NotificationCenter.default.addObserver(self,
            selector: #selector(textChanged), name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView)
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func textChanged(_ n: Notification) { needsDisplay = true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let tv = editorTextView,
              let lm = tv.layoutManager,
              let tc = tv.textContainer,
              let sv = scrollView else { return }

        // Background
        NSColor.controlBackgroundColor.setFill()
        rect.fill()

        // Separator line
        NSColor.separatorColor.setStroke()
        let sepX = bounds.width - 0.5
        NSBezierPath.strokeLine(from: NSPoint(x: sepX, y: rect.minY), to: NSPoint(x: sepX, y: rect.maxY))

        let visibleRect = sv.contentView.bounds
        let glyphRange = lm.glyphRange(forBoundingRect: visibleRect, in: tc)
        let charRange = lm.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let content = tv.string as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        // Count lines before visible range
        var lineNum = 1
        if charRange.location > 0 {
            content.enumerateSubstrings(in: NSRange(location: 0, length: charRange.location),
                                        options: [.byLines, .substringNotRequired]) { _, _, _, _ in lineNum += 1 }
        }

        // Draw visible line numbers
        content.enumerateSubstrings(in: charRange, options: [.byLines, .substringNotRequired]) {
            _, substringRange, _, _ in
            let gr = lm.glyphRange(forCharacterRange: substringRange, actualCharacterRange: nil)
            let lineRect = lm.boundingRect(forGlyphRange: gr, in: tc)
            let y = lineRect.minY - visibleRect.minY
            let str = "\(lineNum)" as NSString
            let sz = str.size(withAttributes: attrs)
            str.draw(at: NSPoint(x: self.gutterWidth - sz.width - 6, y: y), withAttributes: attrs)
            lineNum += 1
        }
    }
}
