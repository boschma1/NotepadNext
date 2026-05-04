import AppKit

/// Status bar at the bottom of the window showing document info.
class StatusBarView: NSView {

    private var lineColLabel: NSTextField!
    private var encodingLabel: NSTextField!
    private var lineEndingLabel: NSTextField!
    private var languageLabel: NSTextField!
    private var lengthLabel: NSTextField!

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

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        lineColLabel = createLabel("Ln 1, Col 1")
        encodingLabel = createLabel("UTF-8")
        lineEndingLabel = createLabel("LF")
        languageLabel = createLabel("Normal Text")
        lengthLabel = createLabel("Length: 0  Lines: 1")

        let stack = NSStackView(views: [
            lineColLabel, createSeparatorDot(),
            lengthLabel, createSeparatorDot(),
            encodingLabel, createSeparatorDot(),
            lineEndingLabel, createSeparatorDot(),
            languageLabel
        ])
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.topAnchor.constraint(equalTo: topAnchor),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1),

            heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    // MARK: - Update

    func update(line: Int, column: Int, length: Int, lines: Int,
                encoding: String, lineEnding: String, language: String) {
        lineColLabel.stringValue = "Ln \(line), Col \(column)"
        lengthLabel.stringValue = "Length: \(length)  Lines: \(lines)"
        encodingLabel.stringValue = encoding
        lineEndingLabel.stringValue = lineEnding
        languageLabel.stringValue = language
    }

    // MARK: - Helpers

    private func createLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func createSeparatorDot() -> NSTextField {
        return createLabel("│")
    }
}
