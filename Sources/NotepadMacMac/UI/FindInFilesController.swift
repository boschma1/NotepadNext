import AppKit

/// Find in Files: search across a directory tree and show results.
class FindInFilesController: NSWindowController {

    private var directoryField: NSTextField!
    private var searchField: NSTextField!
    private var filterField: NSTextField!
    private var matchCaseCheckbox: NSButton!
    private var regexCheckbox: NSButton!
    private var resultsOutline: NSOutlineView!
    private var statusLabel: NSTextField!

    private var results: [FileResult] = []

    struct FileResult {
        let filePath: String
        let fileName: String
        var matches: [MatchResult]
    }

    struct MatchResult {
        let lineNumber: Int
        let lineText: String
        let range: NSRange
    }

    weak var openFileDelegate: FindInFilesDelegate?

    convenience init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered, defer: false
        )
        window.title = "Find in Files"
        window.minSize = NSSize(width: 500, height: 300)
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let cv = window?.contentView else { return }
        let w = cv.bounds.width

        // Directory
        let dirLabel = NSTextField(labelWithString: "Directory:")
        dirLabel.frame = NSRect(x: 8, y: cv.bounds.height - 30, width: 70, height: 20)
        cv.addSubview(dirLabel)

        directoryField = NSTextField(frame: NSRect(x: 80, y: cv.bounds.height - 30, width: w - 170, height: 22))
        directoryField.placeholderString = "/path/to/search"
        directoryField.autoresizingMask = [.width]
        cv.addSubview(directoryField)

        let browseBtn = NSButton(title: "Browse…", target: self, action: #selector(browseDirectory))
        browseBtn.frame = NSRect(x: w - 82, y: cv.bounds.height - 30, width: 74, height: 22)
        browseBtn.autoresizingMask = [.minXMargin]
        cv.addSubview(browseBtn)

        // Search
        let searchLabel = NSTextField(labelWithString: "Find:")
        searchLabel.frame = NSRect(x: 8, y: cv.bounds.height - 58, width: 70, height: 20)
        cv.addSubview(searchLabel)

        searchField = NSTextField(frame: NSRect(x: 80, y: cv.bounds.height - 58, width: w - 170, height: 22))
        searchField.placeholderString = "Search text"
        searchField.autoresizingMask = [.width]
        cv.addSubview(searchField)

        let searchBtn = NSButton(title: "Search", target: self, action: #selector(performSearch))
        searchBtn.frame = NSRect(x: w - 82, y: cv.bounds.height - 58, width: 74, height: 22)
        searchBtn.autoresizingMask = [.minXMargin]
        cv.addSubview(searchBtn)

        // Filters
        let filterLabel = NSTextField(labelWithString: "Filter:")
        filterLabel.frame = NSRect(x: 8, y: cv.bounds.height - 86, width: 70, height: 20)
        cv.addSubview(filterLabel)

        filterField = NSTextField(frame: NSRect(x: 80, y: cv.bounds.height - 86, width: 150, height: 22))
        filterField.stringValue = "*.*"
        filterField.placeholderString = "*.swift, *.py"
        cv.addSubview(filterField)

        matchCaseCheckbox = NSButton(checkboxWithTitle: "Match case", target: nil, action: nil)
        matchCaseCheckbox.frame = NSRect(x: 240, y: cv.bounds.height - 86, width: 100, height: 20)
        cv.addSubview(matchCaseCheckbox)

        regexCheckbox = NSButton(checkboxWithTitle: "Regex", target: nil, action: nil)
        regexCheckbox.frame = NSRect(x: 350, y: cv.bounds.height - 86, width: 80, height: 20)
        cv.addSubview(regexCheckbox)

        // Results
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 24, width: w, height: cv.bounds.height - 114))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true

        resultsOutline = NSOutlineView()
        resultsOutline.headerView = nil
        resultsOutline.rowHeight = 18
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        col.title = "Results"
        resultsOutline.addTableColumn(col)
        resultsOutline.outlineTableColumn = col
        resultsOutline.delegate = self
        resultsOutline.dataSource = self
        resultsOutline.target = self
        resultsOutline.doubleAction = #selector(resultDoubleClicked)

        scrollView.documentView = resultsOutline
        cv.addSubview(scrollView)

        // Status
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: 8, y: 2, width: w - 16, height: 18)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.autoresizingMask = [.width]
        cv.addSubview(statusLabel)
    }

    // MARK: - Actions

    @objc private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            directoryField.stringValue = url.path
        }
    }

    @objc private func performSearch() {
        let dir = directoryField.stringValue
        let query = searchField.stringValue
        guard !dir.isEmpty, !query.isEmpty else { return }

        results = []
        let fm = FileManager.default
        let filter = filterField.stringValue
        let extensions = parseFilter(filter)
        let matchCase = matchCaseCheckbox.state == .on
        let useRegex = regexCheckbox.state == .on

        statusLabel.stringValue = "Searching…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var fileResults: [FileResult] = []
            let enumerator = fm.enumerator(atPath: dir)

            while let relativePath = enumerator?.nextObject() as? String {
                let fullPath = (dir as NSString).appendingPathComponent(relativePath)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue else { continue }

                if !extensions.isEmpty {
                    let ext = (fullPath as NSString).pathExtension.lowercased()
                    if !extensions.contains(ext) && !extensions.contains("*") { continue }
                }

                guard let data = fm.contents(atPath: fullPath),
                      let content = String(data: data, encoding: .utf8) else { continue }

                let lines = content.components(separatedBy: .newlines)
                var matches: [MatchResult] = []

                for (i, line) in lines.enumerated() {
                    if useRegex {
                        var opts: NSRegularExpression.Options = []
                        if !matchCase { opts.insert(.caseInsensitive) }
                        if let regex = try? NSRegularExpression(pattern: query, options: opts),
                           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
                            matches.append(MatchResult(lineNumber: i + 1, lineText: line.trimmingCharacters(in: .whitespaces), range: match.range))
                        }
                    } else {
                        let searchOpts: String.CompareOptions = matchCase ? [] : [.caseInsensitive]
                        if line.range(of: query, options: searchOpts) != nil {
                            matches.append(MatchResult(lineNumber: i + 1, lineText: line.trimmingCharacters(in: .whitespaces), range: NSRange()))
                        }
                    }
                }

                if !matches.isEmpty {
                    fileResults.append(FileResult(filePath: fullPath, fileName: (fullPath as NSString).lastPathComponent, matches: matches))
                }
            }

            DispatchQueue.main.async {
                self.results = fileResults
                self.resultsOutline.reloadData()
                for r in self.results { self.resultsOutline.expandItem(r.filePath) }
                let totalMatches = fileResults.reduce(0) { $0 + $1.matches.count }
                self.statusLabel.stringValue = "\(totalMatches) match(es) in \(fileResults.count) file(s)"
            }
        }
    }

    @objc private func resultDoubleClicked() {
        let row = resultsOutline.clickedRow
        guard row >= 0 else { return }
        let item = resultsOutline.item(atRow: row)
        if let match = item as? MatchInfo {
            openFileDelegate?.findInFiles(self, openFile: match.filePath, atLine: match.lineNumber)
        }
    }

    private func parseFilter(_ filter: String) -> Set<String> {
        var exts = Set<String>()
        for part in filter.components(separatedBy: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed == "*.*" { return ["*"] }
            let ext = trimmed.replacingOccurrences(of: "*.", with: "").lowercased()
            if !ext.isEmpty { exts.insert(ext) }
        }
        return exts
    }

    func showAndFocus(directory: String? = nil) {
        if let dir = directory { directoryField.stringValue = dir }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

// Helper to pass file+line info through outline view
class MatchInfo {
    let filePath: String
    let lineNumber: Int
    let lineText: String
    init(filePath: String, lineNumber: Int, lineText: String) {
        self.filePath = filePath; self.lineNumber = lineNumber; self.lineText = lineText
    }
}

protocol FindInFilesDelegate: AnyObject {
    func findInFiles(_ controller: FindInFilesController, openFile path: String, atLine line: Int)
}

extension FindInFilesController: NSOutlineViewDataSource {
    func outlineView(_ ov: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return results.count }
        if let path = item as? String, let r = results.first(where: { $0.filePath == path }) { return r.matches.count }
        return 0
    }
    func outlineView(_ ov: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return results[index].filePath }
        if let path = item as? String, let r = results.first(where: { $0.filePath == path }) {
            let m = r.matches[index]
            return MatchInfo(filePath: path, lineNumber: m.lineNumber, lineText: m.lineText)
        }
        return ""
    }
    func outlineView(_ ov: NSOutlineView, isItemExpandable item: Any) -> Bool { return item is String }
}

extension FindInFilesController: NSOutlineViewDelegate {
    func outlineView(_ ov: NSOutlineView, viewFor tc: NSTableColumn?, item: Any) -> NSView? {
        let cell = NSTextField(labelWithString: "")
        cell.lineBreakMode = .byTruncatingTail
        if let path = item as? String {
            let r = results.first(where: { $0.filePath == path })
            cell.stringValue = "📄 \((path as NSString).lastPathComponent)  (\(r?.matches.count ?? 0) matches)"
            cell.font = NSFont.boldSystemFont(ofSize: 12)
        } else if let m = item as? MatchInfo {
            cell.stringValue = "  Line \(m.lineNumber): \(m.lineText)"
            cell.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            cell.textColor = .secondaryLabelColor
        }
        return cell
    }
}
