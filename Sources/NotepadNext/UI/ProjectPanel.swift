import AppKit

/// Project Panel — custom file groupings independent of filesystem.
class ProjectPanel: NSView {

    private var outlineView: NSOutlineView!
    private var scrollView: NSScrollView!
    private var projects: [ProjectItem] = []

    weak var delegate: ProjectPanelDelegate?

    class ProjectItem {
        var name: String
        var children: [ProjectFileItem]

        init(name: String) {
            self.name = name
            self.children = []
        }
    }

    class ProjectFileItem {
        let url: URL
        let name: String

        init(url: URL) {
            self.url = url
            self.name = url.lastPathComponent
        }
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

        // Toolbar
        let addProjectBtn = NSButton(title: "+ Project", target: self, action: #selector(addProject))
        addProjectBtn.bezelStyle = .accessoryBarAction
        addProjectBtn.frame = NSRect(x: 4, y: bounds.height - 24, width: 80, height: 20)
        addProjectBtn.autoresizingMask = [.minYMargin]
        addSubview(addProjectBtn)

        let addFileBtn = NSButton(title: "+ File", target: self, action: #selector(addFiles))
        addFileBtn.bezelStyle = .accessoryBarAction
        addFileBtn.frame = NSRect(x: 88, y: bounds.height - 24, width: 60, height: 20)
        addFileBtn.autoresizingMask = [.minYMargin]
        addSubview(addFileBtn)

        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 28))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.rowHeight = 20
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.target = self
        outlineView.doubleAction = #selector(itemDoubleClicked)

        scrollView.documentView = outlineView
        addSubview(scrollView)
    }

    @objc private func addProject() {
        let alert = NSAlert()
        alert.messageText = "New Project"
        alert.informativeText = "Project name:"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = "Project \(projects.count + 1)"
        alert.accessoryView = field
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            projects.append(ProjectItem(name: field.stringValue))
            outlineView.reloadData()
        }
    }

    @objc private func addFiles() {
        guard !projects.isEmpty else {
            addProject()
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            let targetProject = projects.last!
            for url in panel.urls {
                targetProject.children.append(ProjectFileItem(url: url))
            }
            outlineView.reloadData()
            outlineView.expandItem(targetProject)
        }
    }

    @objc private func itemDoubleClicked() {
        let row = outlineView.clickedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? ProjectFileItem else { return }
        delegate?.projectPanel(self, didSelectFile: item.url)
    }
}

protocol ProjectPanelDelegate: AnyObject {
    func projectPanel(_ panel: ProjectPanel, didSelectFile url: URL)
}

extension ProjectPanel: NSOutlineViewDataSource {
    func outlineView(_ ov: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return projects.count }
        if let p = item as? ProjectItem { return p.children.count }
        return 0
    }
    func outlineView(_ ov: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return projects[index] }
        return (item as! ProjectItem).children[index]
    }
    func outlineView(_ ov: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is ProjectItem
    }
}

extension ProjectPanel: NSOutlineViewDelegate {
    func outlineView(_ ov: NSOutlineView, viewFor tc: NSTableColumn?, item: Any) -> NSView? {
        let cell = NSTextField(labelWithString: "")
        cell.lineBreakMode = .byTruncatingTail
        if let p = item as? ProjectItem {
            cell.stringValue = "📁 \(p.name)"
            cell.font = NSFont.boldSystemFont(ofSize: 12)
        } else if let f = item as? ProjectFileItem {
            cell.stringValue = "  📄 \(f.name)"
            cell.font = NSFont.systemFont(ofSize: 12)
        }
        return cell
    }
}
