import AppKit

class LineNumberGutter: NSView {

    private weak var textView: NSTextView?
    private weak var scrollView: NSScrollView?
    static let gutterWidth: CGFloat = 44

    override var isFlipped: Bool { true }

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        self.scrollView = scrollView
        super.init(frame: .zero)
        wantsLayer = true

        for name: Notification.Name in [
            NSText.didChangeNotification,
            NSTextView.didChangeSelectionNotification,
        ] {
            NotificationCenter.default.addObserver(self, selector: #selector(needsRedraw), name: name, object: textView)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(needsRedraw),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }

    required init?(coder: NSCoder) { fatalError() }
    @objc private func needsRedraw() { needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        guard let tv = textView, let sv = scrollView,
              let lm = tv.layoutManager, let tc = tv.textContainer else { return }

        // Background
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        NSColor.separatorColor.setStroke()
        NSBezierPath.strokeLine(from: NSPoint(x: bounds.width - 0.5, y: 0),
                                to: NSPoint(x: bounds.width - 0.5, y: bounds.height))

        let visibleRect = sv.contentView.bounds
        let text = tv.string as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        guard text.length > 0 else {
            // Empty document: draw "1"
            let s = "1" as NSString
            let sz = s.size(withAttributes: attrs)
            s.draw(at: NSPoint(x: bounds.width - sz.width - 6, y: 1), withAttributes: attrs)
            return
        }

        // Ensure layout is complete
        lm.ensureLayout(for: tc)

        var lineNumber = 1
        var charIndex = 0

        while charIndex <= text.length {
            // Get the rect for this character position
            let y: CGFloat
            if charIndex < text.length {
                let glyphIndex = lm.glyphIndexForCharacter(at: charIndex)
                let fragRect = lm.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                y = fragRect.minY - visibleRect.minY
            } else {
                // Last line after trailing newline: position below the last glyph
                let lastGlyph = lm.glyphIndexForCharacter(at: text.length - 1)
                let fragRect = lm.lineFragmentRect(forGlyphAt: lastGlyph, effectiveRange: nil)
                y = fragRect.maxY - visibleRect.minY
            }

            if y >= -20 && y <= bounds.height + 20 {
                let s = "\(lineNumber)" as NSString
                let sz = s.size(withAttributes: attrs)
                s.draw(at: NSPoint(x: bounds.width - sz.width - 6, y: y + 1), withAttributes: attrs)
            }

            // Find next line
            if charIndex >= text.length { break }
            let lineRange = text.lineRange(for: NSRange(location: charIndex, length: 0))
            let nextIndex = NSMaxRange(lineRange)
            if nextIndex <= charIndex { break }

            lineNumber += 1
            charIndex = nextIndex
        }
    }
}
