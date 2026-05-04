import AppKit

class StatusBarView: NSView {

    private var label: NSTextField!

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

        let separator = NSBox(frame: NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1))
        separator.boxType = .separator
        separator.autoresizingMask = [.width, .minYMargin]
        addSubview(separator)

        label = NSTextField(labelWithString: "Ln 1, Col 1 │ UTF-8 │ LF │ Normal Text")
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 8, y: 1, width: bounds.width - 16, height: bounds.height - 2)
        label.autoresizingMask = [.width]
        addSubview(label)
    }

    func update(line: Int, column: Int, length: Int, lines: Int, words: Int,
                encoding: String, lineEnding: String, language: String) {
        label.stringValue = "Ln \(line), Col \(column) │ Words: \(words)  Length: \(length)  Lines: \(lines) │ \(encoding) │ \(lineEnding) │ \(language)"
    }
}
