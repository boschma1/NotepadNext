import AppKit

/// User Defined Language editor — create custom syntax rules.
class UDLEditorController: NSWindowController {

    private var nameField: NSTextField!
    private var extensionsField: NSTextField!
    private var keywordsField: NSTextView!
    private var lineCommentField: NSTextField!
    private var blockCommentOpenField: NSTextField!
    private var blockCommentCloseField: NSTextField!

    convenience init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "User Defined Language"
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let cv = window?.contentView else { return }
        var y: CGFloat = cv.bounds.height - 36

        // Name
        let nameLabel = NSTextField(labelWithString: "Language name:")
        nameLabel.frame = NSRect(x: 16, y: y, width: 120, height: 20)
        cv.addSubview(nameLabel)

        nameField = NSTextField(frame: NSRect(x: 140, y: y, width: 250, height: 22))
        nameField.placeholderString = "My Language"
        cv.addSubview(nameField)
        y -= 32

        // Extensions
        let extLabel = NSTextField(labelWithString: "File extensions:")
        extLabel.frame = NSRect(x: 16, y: y, width: 120, height: 20)
        cv.addSubview(extLabel)

        extensionsField = NSTextField(frame: NSRect(x: 140, y: y, width: 250, height: 22))
        extensionsField.placeholderString = "myext myx"
        cv.addSubview(extensionsField)
        y -= 32

        // Line comment
        let lcLabel = NSTextField(labelWithString: "Line comment:")
        lcLabel.frame = NSRect(x: 16, y: y, width: 120, height: 20)
        cv.addSubview(lcLabel)

        lineCommentField = NSTextField(frame: NSRect(x: 140, y: y, width: 100, height: 22))
        lineCommentField.placeholderString = "//"
        cv.addSubview(lineCommentField)
        y -= 32

        // Block comment
        let bcLabel = NSTextField(labelWithString: "Block comment:")
        bcLabel.frame = NSRect(x: 16, y: y, width: 120, height: 20)
        cv.addSubview(bcLabel)

        blockCommentOpenField = NSTextField(frame: NSRect(x: 140, y: y, width: 60, height: 22))
        blockCommentOpenField.placeholderString = "/*"
        cv.addSubview(blockCommentOpenField)

        let toLabel = NSTextField(labelWithString: "to")
        toLabel.frame = NSRect(x: 205, y: y, width: 20, height: 20)
        cv.addSubview(toLabel)

        blockCommentCloseField = NSTextField(frame: NSRect(x: 230, y: y, width: 60, height: 22))
        blockCommentCloseField.placeholderString = "*/"
        cv.addSubview(blockCommentCloseField)
        y -= 36

        // Keywords
        let kwLabel = NSTextField(labelWithString: "Keywords (one per line):")
        kwLabel.frame = NSRect(x: 16, y: y, width: 200, height: 20)
        cv.addSubview(kwLabel)
        y -= 8

        let scrollView = NSScrollView(frame: NSRect(x: 16, y: y - 160, width: cv.bounds.width - 32, height: 160))
        scrollView.hasVerticalScroller = true
        keywordsField = NSTextView(frame: scrollView.contentView.bounds)
        keywordsField.autoresizingMask = [.width]
        keywordsField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        scrollView.documentView = keywordsField
        cv.addSubview(scrollView)
        y -= 170

        // Buttons
        let saveBtn = NSButton(title: "Save Language", target: self, action: #selector(saveLanguage))
        saveBtn.frame = NSRect(x: cv.bounds.width - 140, y: 12, width: 120, height: 28)
        saveBtn.bezelStyle = .rounded
        cv.addSubview(saveBtn)

        let importBtn = NSButton(title: "Import XML…", target: self, action: #selector(importXML))
        importBtn.frame = NSRect(x: 16, y: 12, width: 110, height: 28)
        cv.addSubview(importBtn)
    }

    @objc private func saveLanguage() {
        let name = nameField.stringValue
        guard !name.isEmpty else { NSSound.beep(); return }

        let udl = UserDefinedLanguage(
            name: name,
            extensions: extensionsField.stringValue.components(separatedBy: " ").filter { !$0.isEmpty },
            lineComment: lineCommentField.stringValue,
            blockCommentOpen: blockCommentOpenField.stringValue,
            blockCommentClose: blockCommentCloseField.stringValue,
            keywords: keywordsField.string.components(separatedBy: .newlines).filter { !$0.isEmpty }
        )

        UDLManager.shared.addLanguage(udl)

        let alert = NSAlert()
        alert.messageText = "Language Saved"
        alert.informativeText = "\"\(name)\" has been added to the Language menu."
        alert.runModal()
    }

    @objc private func importXML() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml]
        if panel.runModal() == .OK, let url = panel.url {
            // Basic XML import — reads Notepad++ UDL format
            if let data = try? Data(contentsOf: url),
               let content = String(data: data, encoding: .utf8) {
                // Extract name from XML
                if let nameRange = content.range(of: #"name="([^"]+)""#, options: .regularExpression) {
                    let match = content[nameRange]
                    let name = String(match.dropFirst(6).dropLast(1))
                    nameField.stringValue = name
                }
                let alert = NSAlert()
                alert.messageText = "XML Imported"
                alert.informativeText = "Review the fields and click Save Language to add it."
                alert.runModal()
            }
        }
    }

    func showAndFocus() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - UDL Data Model

struct UserDefinedLanguage {
    let name: String
    let extensions: [String]
    let lineComment: String
    let blockCommentOpen: String
    let blockCommentClose: String
    let keywords: [String]
}

class UDLManager {
    static let shared = UDLManager()
    private(set) var languages: [UserDefinedLanguage] = []

    func addLanguage(_ lang: UserDefinedLanguage) {
        // Remove existing with same name
        languages.removeAll { $0.name == lang.name }
        languages.append(lang)
        save()
    }

    private var storageURL: URL {
        AppConfig.configDirectory.appendingPathComponent("userDefinedLanguages.json")
    }

    func save() {
        AppConfig.ensureConfigDirectory()
        let entries = languages.map { lang -> [String: Any] in
            return [
                "name": lang.name,
                "extensions": lang.extensions,
                "lineComment": lang.lineComment,
                "blockCommentOpen": lang.blockCommentOpen,
                "blockCommentClose": lang.blockCommentClose,
                "keywords": lang.keywords,
            ]
        }
        if let data = try? JSONSerialization.data(withJSONObject: entries, options: .prettyPrinted) {
            try? data.write(to: storageURL)
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        languages = entries.compactMap { entry in
            guard let name = entry["name"] as? String else { return nil }
            return UserDefinedLanguage(
                name: name,
                extensions: entry["extensions"] as? [String] ?? [],
                lineComment: entry["lineComment"] as? String ?? "",
                blockCommentOpen: entry["blockCommentOpen"] as? String ?? "",
                blockCommentClose: entry["blockCommentClose"] as? String ?? "",
                keywords: entry["keywords"] as? [String] ?? []
            )
        }
    }
}
