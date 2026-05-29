import AppKit

/// NSLayoutManager subclass that can overlay visible symbols for normally
/// invisible "formatting" characters: tabs, spaces, and line endings.
///
/// Unlike NSLayoutManager.showsInvisibleCharacters (which renders a single
/// pilcrow glyph for any newline), this class distinguishes:
///   - LF only   → "LF"
///   - CR only   → "CR"
///   - CRLF      → "CRLF"   (drawn once at the position of the CR)
///   - TAB       → "→"
///   - SPACE     → "·"
/// The symbols are drawn as a non-intrusive overlay in tertiary label color,
/// so the underlying text layout (line widths, cursor positions, selection
/// geometry) is unchanged.
class InvisiblesLayoutManager: NSLayoutManager {

    var showsFormattingMarks: Bool = false {
        didSet {
            guard oldValue != showsFormattingMarks, let storage = textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)
            invalidateDisplay(forCharacterRange: fullRange)
        }
    }

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard showsFormattingMarks else { return }
        drawFormattingMarks(forGlyphRange: glyphsToShow, at: origin)
    }

    private func drawFormattingMarks(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        guard let storage = textStorage, storage.length > 0,
              let container = textContainer(forGlyphAt: glyphsToShow.location,
                                            effectiveRange: nil)
        else { return }

        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let str = storage.string as NSString

        let probeIndex = max(min(charRange.location, storage.length - 1), 0)
        let baseFont = (storage.attribute(.font, at: probeIndex, effectiveRange: nil) as? NSFont)
            ?? NSFont.systemFont(ofSize: 12)
        let symbolFont = NSFont.systemFont(ofSize: baseFont.pointSize * 0.85)

        let inlineAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let lineEndingAttrs: [NSAttributedString.Key: Any] = [
            .font: symbolFont,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        var i = charRange.location
        let end = min(NSMaxRange(charRange), str.length)
        while i < end {
            let ch = str.character(at: i)
            let glyphIndex = glyphIndexForCharacter(at: i)
            switch ch {
            case 0x09:  // TAB
                let rect = boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1),
                                        in: container)
                let pt = NSPoint(x: origin.x + rect.minX, y: origin.y + rect.minY)
                ("→" as NSString).draw(at: pt, withAttributes: inlineAttrs)
            case 0x20:  // SPACE
                let rect = boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1),
                                        in: container)
                let dot: NSString = "·"
                let dotSize = dot.size(withAttributes: inlineAttrs)
                let x = origin.x + rect.midX - dotSize.width / 2
                let y = origin.y + rect.minY
                dot.draw(at: NSPoint(x: x, y: y), withAttributes: inlineAttrs)
            case 0x0D:  // CR (potentially CRLF)
                let isCRLF = (i + 1 < str.length && str.character(at: i + 1) == 0x0A)
                let label = isCRLF ? "CRLF" : "CR"
                drawLineEndingLabel(label, glyphIndex: glyphIndex, in: container,
                                    origin: origin, attrs: lineEndingAttrs)
                if isCRLF { i += 1 }  // consume the LF half of CRLF
            case 0x0A:  // LF (standalone; LF that follows CR was skipped above)
                drawLineEndingLabel("LF", glyphIndex: glyphIndex, in: container,
                                    origin: origin, attrs: lineEndingAttrs)
            default:
                break
            }
            i += 1
        }
    }

    private func drawLineEndingLabel(_ label: String, glyphIndex: Int,
                                     in container: NSTextContainer, origin: NSPoint,
                                     attrs: [NSAttributedString.Key: Any]) {
        // Line break glyphs have zero visible width; the marker goes at the
        // end of the line's used rect, i.e. just past the last drawn character.
        let lineRect = lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        let labelString = label as NSString
        let labelSize = labelString.size(withAttributes: attrs)
        let yPad = max(0, (lineRect.height - labelSize.height) / 2)
        let drawPoint = NSPoint(x: origin.x + lineRect.maxX + 2,
                                y: origin.y + lineRect.minY + yPad)
        labelString.draw(at: drawPoint, withAttributes: attrs)
    }
}
