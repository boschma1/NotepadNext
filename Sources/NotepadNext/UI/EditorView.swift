import AppKit

protocol EditorViewDelegate: AnyObject {
    func editorViewDidChange(_ editorView: EditorView)
}

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
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                   height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        textView.textStorage?.delegate = syntaxHighlighter
        addSubview(scrollView)
        textView.delegate = self
    }
}

extension EditorView: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        delegate?.editorViewDidChange(self)
    }
}
