import AppKit

/// Manages a second editor view for split/dual view editing.
class SplitViewManager {

    private weak var mainController: MainWindowController?
    private(set) var secondScrollView: NSScrollView?
    private(set) var secondTextView: NSTextView?
    private(set) var isActive = false
    private var isVertical = true  // true = side-by-side, false = top-bottom

    init(mainController: MainWindowController) {
        self.mainController = mainController
    }

    func toggle(in contentView: NSView, editorFrame: NSRect) {
        if isActive {
            deactivate()
        } else {
            activate(in: contentView, editorFrame: editorFrame)
        }
    }

    func activate(in contentView: NSView, editorFrame: NSRect) {
        guard !isActive else { return }

        // Start with a real (non-zero) frame so the clip view has usable
        // bounds — otherwise the document text view is born at .zero and
        // never recovers a usable height when the scroll view is resized
        // later, making the second pane invisible / unscrollable.
        secondScrollView = NSScrollView(frame: editorFrame)
        secondScrollView!.autoresizingMask = [.width, .height]
        secondScrollView!.hasVerticalScroller = true
        secondScrollView!.hasHorizontalScroller = true

        secondTextView = PlainTextView(frame: secondScrollView!.contentView.bounds)
        secondTextView!.autoresizingMask = [.width]
        secondTextView!.isEditable = true
        secondTextView!.isSelectable = true
        secondTextView!.allowsUndo = true
        secondTextView!.isAutomaticQuoteSubstitutionEnabled = false
        secondTextView!.isAutomaticDashSubstitutionEnabled = false
        secondTextView!.isAutomaticTextReplacementEnabled = false
        secondTextView!.isAutomaticSpellingCorrectionEnabled = false
        secondTextView!.smartInsertDeleteEnabled = false
        let theme = ThemeManager.shared.currentTheme
        secondTextView!.font = theme.editorFont
        secondTextView!.textColor = theme.foreground
        secondTextView!.backgroundColor = theme.background
        secondTextView!.insertionPointColor = theme.caretColor
        secondTextView!.isHorizontallyResizable = true
        secondTextView!.isVerticallyResizable = true
        secondTextView!.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                          height: CGFloat.greatestFiniteMagnitude)
        secondTextView!.textContainer?.widthTracksTextView = false
        secondTextView!.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                               height: CGFloat.greatestFiniteMagnitude)

        secondScrollView!.documentView = secondTextView
        secondTextView!.delegate = mainController
        contentView.addSubview(secondScrollView!)

        // Clone current content
        if let mainText = mainController?.textView.string {
            secondTextView!.string = mainText
        }

        isActive = true
    }

    func deactivate() {
        secondScrollView?.removeFromSuperview()
        secondScrollView = nil
        secondTextView = nil
        isActive = false
    }

    func toggleOrientation() {
        isVertical.toggle()
    }

    /// Returns (mainFrame, secondFrame) given the available editor area.
    func splitFrames(for editorFrame: NSRect) -> (NSRect, NSRect)? {
        guard isActive else { return nil }

        if isVertical {
            let half = editorFrame.width / 2 - 1
            let mainFrame = NSRect(x: editorFrame.minX, y: editorFrame.minY,
                                    width: half, height: editorFrame.height)
            let secondFrame = NSRect(x: editorFrame.minX + half + 2, y: editorFrame.minY,
                                      width: half, height: editorFrame.height)
            return (mainFrame, secondFrame)
        } else {
            let half = editorFrame.height / 2 - 1
            let mainFrame = NSRect(x: editorFrame.minX, y: editorFrame.minY + half + 2,
                                    width: editorFrame.width, height: half)
            let secondFrame = NSRect(x: editorFrame.minX, y: editorFrame.minY,
                                      width: editorFrame.width, height: half)
            return (mainFrame, secondFrame)
        }
    }
}
