import AppKit

/// Line number view placed alongside the editor scroll view.
/// Flipped coordinate system to match text view (top-down).
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

        NotificationCenter.default.addObserver(self,
            selector: #selector(needsRedraw), name: NSText.didChangeNotification, object: textView)
        NotificationCenter.default.addObserver(self,
            selector: #selector(needsRedraw), name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView)
        NotificationCenter.default.addObserver(self,
            selector: #selector(needsRedraw), name: NSView.frameDidChangeNotification,
            object: scrollView.contentView)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func needsRedraw() { needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        guard let tv = textView, let sv = scrollView,
              let lm = tv.layoutManager, let tc = tv.textContainer else { return }

        // Background
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        // Right separator
        NSColor.separatorColor.setStroke()
        NSBezierPath.strokeLine(from: NSPoint(x: bounds.width - 0.5, y: 0),
                                to: NSPoint(x: bounds.width - 0.5, y: bounds.height))

        let visibleRect = sv.contentView.bounds
        let glyphRange = lm.glyphRange(forBoundingRect: visibleRect, in: tc)
        let charRange = lm.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let content = tv.string as NSString
        guard content.length > 0 else { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        // Count lines before visible range
        var lineNum = 1
        if charRange.location > 0 {
            let before = content.substring(to: charRange.location)
            lineNum = before.components(separatedBy: "\n").count
        }

        // Draw visible line numbers
        var index = charRange.location
        while index < content.length && index <= NSMaxRange(charRange) {
            let lineRange = content.lineRange(for: NSRange(location: index, length: 0))
            let glyphs = lm.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)

            if glyphs.location != NSNotFound {
                let lineRect = lm.boundingRect(forGlyphRange: glyphs, in: tc)
                // y position relative to visible area (top-down since isFlipped)
                let y = lineRect.minY - visibleRect.minY

                if y >= -20 && y <= bounds.height + 20 {
                    let str = "\(lineNum)" as NSString
                    let sz = str.size(withAttributes: attrs)
                    str.draw(at: NSPoint(x: bounds.width - sz.width - 6, y: y + 1), withAttributes: attrs)
                }
            }

            lineNum += 1
            let next = NSMaxRange(lineRange)
            if next <= index { break }
            index = next
        }

        // Draw line number for the final empty line (after trailing newline or empty document)
        if content.length == 0 || content.character(at: content.length - 1) == 0x0A {
            let extraGlyphIndex = lm.glyphIndexForCharacter(at: max(0, content.length - 1))
            var lineRect = lm.lineFragmentRect(forGlyphAt: extraGlyphIndex, effectiveRange: nil)
            // Position below the last line
            if content.length > 0 {
                lineRect.origin.y = lineRect.maxY
            }
            let y = lineRect.origin.y - visibleRect.minY
            if y >= -20 && y <= bounds.height + 20 {
                let str = "\(lineNum)" as NSString
                let sz = str.size(withAttributes: attrs)
                str.draw(at: NSPoint(x: bounds.width - sz.width - 6, y: y + 1), withAttributes: attrs)
            }
        }
    }
}
