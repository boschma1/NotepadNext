import AppKit

/// Minimap panel showing a zoomed-out view of the current document.
class DocumentMapView: NSView {

    private var miniTextView: NSTextView!
    private var scrollView: NSScrollView!
    private var highlightBox: NSView!
    private weak var sourceTextView: NSTextView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        wantsLayer = true

        scrollView = NSScrollView(frame: bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        miniTextView = NSTextView(frame: scrollView.contentView.bounds)
        miniTextView.isEditable = false
        miniTextView.isSelectable = false
        miniTextView.font = NSFont.monospacedSystemFont(ofSize: 1.5, weight: .regular)
        miniTextView.backgroundColor = .textBackgroundColor
        miniTextView.autoresizingMask = [.width]

        scrollView.documentView = miniTextView
        addSubview(scrollView)

        // Visible area highlight
        highlightBox = NSView()
        highlightBox.wantsLayer = true
        highlightBox.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        highlightBox.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
        highlightBox.layer?.borderWidth = 1
        addSubview(highlightBox)

        // Click to navigate
        let click = NSClickGestureRecognizer(target: self, action: #selector(mapClicked(_:)))
        addGestureRecognizer(click)
    }

    func attachToEditor(_ textView: NSTextView) {
        sourceTextView = textView
        NotificationCenter.default.addObserver(self,
            selector: #selector(sourceTextChanged), name: NSText.didChangeNotification, object: textView)
        if let sv = textView.enclosingScrollView {
            NotificationCenter.default.addObserver(self,
                selector: #selector(sourceScrolled), name: NSView.boundsDidChangeNotification,
                object: sv.contentView)
        }
        updateContent()
    }

    @objc private func sourceTextChanged(_ n: Notification) {
        updateContent()
    }

    @objc private func sourceScrolled(_ n: Notification) {
        updateHighlight()
    }

    private func updateContent() {
        guard let source = sourceTextView else { return }
        miniTextView.string = source.string
        updateHighlight()
    }

    private func updateHighlight() {
        guard let source = sourceTextView,
              let sourceSV = source.enclosingScrollView,
              let sourceLM = source.layoutManager,
              let miniLM = miniTextView.layoutManager,
              let sourceTC = source.textContainer,
              let miniTC = miniTextView.textContainer else { return }

        let sourceVisible = sourceSV.contentView.bounds
        let sourceTotal = sourceLM.usedRect(for: sourceTC).height
        guard sourceTotal > 0 else { return }

        let miniTotal = miniLM.usedRect(for: miniTC).height
        let ratio = miniTotal / sourceTotal

        let highlightY = sourceVisible.origin.y * ratio
        let highlightH = sourceVisible.height * ratio

        highlightBox.frame = NSRect(x: 0, y: bounds.height - highlightY - highlightH,
                                     width: bounds.width, height: max(highlightH, 4))
    }

    @objc private func mapClicked(_ gesture: NSClickGestureRecognizer) {
        guard let source = sourceTextView,
              let sourceSV = source.enclosingScrollView,
              let sourceLM = source.layoutManager,
              let sourceTC = source.textContainer else { return }

        let clickPoint = gesture.location(in: self)
        let fraction = 1.0 - (clickPoint.y / bounds.height)
        let sourceTotal = sourceLM.usedRect(for: sourceTC).height
        let targetY = fraction * sourceTotal - sourceSV.contentView.bounds.height / 2

        sourceSV.contentView.scroll(to: NSPoint(x: 0, y: max(0, targetY)))
        sourceSV.reflectScrolledClipView(sourceSV.contentView)
    }
}
