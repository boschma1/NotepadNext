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

        // Empty document: just draw "1"
        guard text.length > 0 else {
            drawNumber(1, y: 1, attrs: attrs)
            return
        }

        lm.ensureLayout(for: tc)

        // Iterate through each line using lineRange
        var lineNumber = 1
        var charIndex = 0

        while charIndex < text.length {
            let lineRange = text.lineRange(for: NSRange(location: charIndex, length: 0))

            let glyphIndex = lm.glyphIndexForCharacter(at: lineRange.location)
            let fragRect = lm.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let y = fragRect.minY - visibleRect.minY

            if y >= -20 && y <= bounds.height + 20 {
                drawNumber(lineNumber, y: y + 1, attrs: attrs)
            }

            lineNumber += 1
            let nextIndex = NSMaxRange(lineRange)
            if nextIndex <= charIndex { break }
            charIndex = nextIndex
        }

        // If text ends with \n, there's one more empty line to number
        if text.character(at: text.length - 1) == 0x0A {
            let lastGlyph = lm.glyphIndexForCharacter(at: text.length - 1)
            let fragRect = lm.lineFragmentRect(forGlyphAt: lastGlyph, effectiveRange: nil)
            let y = fragRect.maxY - visibleRect.minY

            if y >= -20 && y <= bounds.height + 20 {
                drawNumber(lineNumber, y: y + 1, attrs: attrs)
            }
        }
    }

    private func drawNumber(_ n: Int, y: CGFloat, attrs: [NSAttributedString.Key: Any]) {
        let s = "\(n)" as NSString
        let sz = s.size(withAttributes: attrs)
        s.draw(at: NSPoint(x: bounds.width - sz.width - 6, y: y), withAttributes: attrs)
    }
}
