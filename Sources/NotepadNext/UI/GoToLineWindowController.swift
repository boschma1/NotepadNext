import AppKit

/// Go to Line dialog.
class GoToLineWindowController: NSWindowController {

    private var lineField: NSTextField!
    private weak var targetTextView: NSTextView?

    convenience init(textView: NSTextView) {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Go to Line"

        self.init(window: window)
        self.targetTextView = textView
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let label = NSTextField(labelWithString: "Line number:")
        lineField = NSTextField()
        lineField.placeholderString = "1"

        let goButton = NSButton(title: "Go", target: self, action: #selector(goToLine))
        goButton.keyEquivalent = "\r"

        let stack = NSStackView(views: [label, lineField, goButton])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            lineField.widthAnchor.constraint(equalToConstant: 100),
        ])
    }

    @objc private func goToLine() {
        guard let tv = targetTextView,
              let lineNum = Int(lineField.stringValue), lineNum > 0 else {
            NSSound.beep()
            return
        }

        let content = tv.string as NSString
        var currentLine = 1
        var targetLocation = 0

        content.enumerateSubstrings(
            in: NSRange(location: 0, length: content.length),
            options: [.byLines, .substringNotRequired]
        ) { _, substringRange, _, stop in
            if currentLine == lineNum {
                targetLocation = substringRange.location
                stop.pointee = true
            }
            currentLine += 1
        }

        if lineNum >= currentLine {
            targetLocation = content.length
        }

        tv.setSelectedRange(NSRange(location: targetLocation, length: 0))
        tv.scrollRangeToVisible(NSRange(location: targetLocation, length: 0))
        window?.close()
    }

    func showAndFocus() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(lineField)
    }
}
