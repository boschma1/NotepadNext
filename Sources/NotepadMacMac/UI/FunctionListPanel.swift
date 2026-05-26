import AppKit

/// Function List panel — parses functions/classes from the current document.
class FunctionListPanel: NSView {

    private var outlineView: NSOutlineView!
    private var scrollView: NSScrollView!
    private var items: [FunctionItem] = []

    weak var delegate: FunctionListDelegate?

    struct FunctionItem {
        let name: String
        let kind: String  // "func", "class", "struct", etc.
        let lineNumber: Int
        let icon: String
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
        wantsLayer = true

        let titleLabel = NSTextField(labelWithString: "Functions")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 11)
        titleLabel.frame = NSRect(x: 8, y: bounds.height - 20, width: bounds.width - 16, height: 16)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        addSubview(titleLabel)

        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 24))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.rowHeight = 18

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("func"))
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col

        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.target = self
        outlineView.doubleAction = #selector(itemClicked)

        scrollView.documentView = outlineView
        addSubview(scrollView)
    }

    /// Parse functions from the given text and language.
    func parse(text: String, language: String) {
        items = []

        let lines = text.components(separatedBy: .newlines)
        let patterns = patternsForLanguage(language)

        for (i, line) in lines.enumerated() {
            for (pattern, kind, icon) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
                let nsLine = line as NSString
                if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let nameRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
                    if nameRange.location != NSNotFound {
                        let name = nsLine.substring(with: nameRange)
                        items.append(FunctionItem(name: name, kind: kind, lineNumber: i + 1, icon: icon))
                    }
                }
            }
        }

        outlineView.reloadData()
    }

    private func patternsForLanguage(_ lang: String) -> [(String, String, String)] {
        switch lang {
        case "Swift":
            return [
                (#"^\s*(?:public |private |internal |open |fileprivate )?func\s+(\w+)"#, "func", "ƒ"),
                (#"^\s*(?:public |private |internal |open |fileprivate )?class\s+(\w+)"#, "class", "C"),
                (#"^\s*(?:public |private |internal |open |fileprivate )?struct\s+(\w+)"#, "struct", "S"),
                (#"^\s*(?:public |private |internal |open |fileprivate )?enum\s+(\w+)"#, "enum", "E"),
                (#"^\s*(?:public |private |internal |open |fileprivate )?protocol\s+(\w+)"#, "protocol", "P"),
            ]
        case "Python":
            return [
                (#"^\s*def\s+(\w+)"#, "def", "ƒ"),
                (#"^\s*class\s+(\w+)"#, "class", "C"),
            ]
        case "JavaScript", "TypeScript":
            return [
                (#"^\s*(?:export\s+)?(?:async\s+)?function\s+(\w+)"#, "function", "ƒ"),
                (#"^\s*(?:export\s+)?class\s+(\w+)"#, "class", "C"),
                (#"^\s*(\w+)\s*(?:=|:)\s*(?:async\s+)?\([^)]*\)\s*=>"#, "arrow", "ƒ"),
            ]
        case "Java", "C#":
            return [
                (#"^\s*(?:public|private|protected|static|\s)*\s+\w+\s+(\w+)\s*\("#, "method", "ƒ"),
                (#"^\s*(?:public |private |protected )?class\s+(\w+)"#, "class", "C"),
                (#"^\s*(?:public |private |protected )?interface\s+(\w+)"#, "interface", "I"),
            ]
        case "C", "C++", "Objective-C":
            return [
                (#"^\s*(?:\w+[\s*]+)+(\w+)\s*\([^;]*$"#, "function", "ƒ"),
                (#"^\s*class\s+(\w+)"#, "class", "C"),
                (#"^\s*struct\s+(\w+)"#, "struct", "S"),
            ]
        case "Go":
            return [
                (#"^func\s+(?:\(\w+\s+\*?\w+\)\s+)?(\w+)"#, "func", "ƒ"),
                (#"^type\s+(\w+)\s+struct"#, "struct", "S"),
                (#"^type\s+(\w+)\s+interface"#, "interface", "I"),
            ]
        case "Rust":
            return [
                (#"^\s*(?:pub\s+)?fn\s+(\w+)"#, "fn", "ƒ"),
                (#"^\s*(?:pub\s+)?struct\s+(\w+)"#, "struct", "S"),
                (#"^\s*(?:pub\s+)?enum\s+(\w+)"#, "enum", "E"),
                (#"^\s*(?:pub\s+)?trait\s+(\w+)"#, "trait", "T"),
                (#"^\s*impl(?:<[^>]+>)?\s+(\w+)"#, "impl", "I"),
            ]
        case "Ruby":
            return [
                (#"^\s*def\s+(\w+)"#, "def", "ƒ"),
                (#"^\s*class\s+(\w+)"#, "class", "C"),
                (#"^\s*module\s+(\w+)"#, "module", "M"),
            ]
        case "PHP":
            return [
                (#"^\s*(?:public |private |protected |static )*function\s+(\w+)"#, "function", "ƒ"),
                (#"^\s*class\s+(\w+)"#, "class", "C"),
            ]
        case "Shell":
            return [
                (#"^\s*(?:function\s+)?(\w+)\s*\(\)"#, "function", "ƒ"),
            ]
        case "Markdown":
            return [
                (#"^(#{1,6}\s+.+)$"#, "heading", "#"),
            ]
        default:
            return [
                (#"^\s*(?:function|func|def|sub|proc)\s+(\w+)"#, "function", "ƒ"),
            ]
        }
    }

    @objc private func itemClicked() {
        let row = outlineView.clickedRow
        guard row >= 0, row < items.count else { return }
        delegate?.functionList(self, didSelectFunction: items[row].lineNumber)
    }
}

protocol FunctionListDelegate: AnyObject {
    func functionList(_ panel: FunctionListPanel, didSelectFunction lineNumber: Int)
}

extension FunctionListPanel: NSOutlineViewDataSource {
    func outlineView(_ ov: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return item == nil ? items.count : 0
    }
    func outlineView(_ ov: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return index
    }
    func outlineView(_ ov: NSOutlineView, isItemExpandable item: Any) -> Bool { false }
}

extension FunctionListPanel: NSOutlineViewDelegate {
    func outlineView(_ ov: NSOutlineView, viewFor tc: NSTableColumn?, item: Any) -> NSView? {
        guard let idx = item as? Int, idx < items.count else { return nil }
        let fi = items[idx]
        let cell = NSTextField(labelWithString: "\(fi.icon) \(fi.name)  :\(fi.lineNumber)")
        cell.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        cell.lineBreakMode = .byTruncatingTail
        return cell
    }
}
