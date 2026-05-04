import AppKit

protocol FolderWorkspaceDelegate: AnyObject {
    func folderWorkspace(_ panel: FolderWorkspacePanel, didSelectFile url: URL)
}

/// Tree-based file browser panel, similar to Notepad++'s "Folder as Workspace".
class FolderWorkspacePanel: NSView {

    weak var delegate: FolderWorkspaceDelegate?

    private var outlineView: NSOutlineView!
    private var scrollView: NSScrollView!
    private var rootItems: [FileItem] = []

    class FileItem {
        let url: URL
        let name: String
        let isDirectory: Bool
        var children: [FileItem]?

        init(url: URL) {
            self.url = url
            self.name = url.lastPathComponent
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            self.isDirectory = isDir.boolValue
        }

        func loadChildren() {
            guard isDirectory, children == nil else { return }
            let fm = FileManager.default
            guard let urls = try? fm.contentsOfDirectory(at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]) else {
                children = []
                return
            }
            children = urls.sorted { a, b in
                let aDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let bDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if aDir != bDir { return aDir }
                return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
            }.map { FileItem(url: $0) }
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
        scrollView = NSScrollView(frame: bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.rowHeight = 20
        outlineView.indentationPerLevel = 16

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col.title = "Name"
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col

        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.target = self
        outlineView.doubleAction = #selector(itemDoubleClicked)

        scrollView.documentView = outlineView
        addSubview(scrollView)
    }

    func addFolder(_ url: URL) {
        let item = FileItem(url: url)
        item.loadChildren()
        rootItems.append(item)
        outlineView.reloadData()
        outlineView.expandItem(item)
    }

    func removeAllFolders() {
        rootItems.removeAll()
        outlineView.reloadData()
    }

    @objc private func itemDoubleClicked() {
        let row = outlineView.clickedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? FileItem else { return }
        if !item.isDirectory {
            delegate?.folderWorkspace(self, didSelectFile: item.url)
        }
    }
}

extension FolderWorkspacePanel: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return rootItems.count }
        guard let fi = item as? FileItem else { return 0 }
        fi.loadChildren()
        return fi.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return rootItems[index] }
        let fi = item as! FileItem
        fi.loadChildren()
        return fi.children![index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return (item as? FileItem)?.isDirectory ?? false
    }
}

extension FolderWorkspacePanel: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let fi = item as? FileItem else { return nil }

        let cellId = NSUserInterfaceItemIdentifier("FileCell")
        let cell: NSTableCellView
        if let existing = outlineView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = cellId
            let imgView = NSImageView()
            let textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingTail
            imgView.translatesAutoresizingMaskIntoConstraints = false
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(imgView)
            cell.addSubview(textField)
            cell.imageView = imgView
            cell.textField = textField
            NSLayoutConstraint.activate([
                imgView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imgView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imgView.widthAnchor.constraint(equalToConstant: 16),
                imgView.heightAnchor.constraint(equalToConstant: 16),
                textField.leadingAnchor.constraint(equalTo: imgView.trailingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        cell.textField?.stringValue = fi.name
        cell.textField?.font = NSFont.systemFont(ofSize: 12)
        cell.imageView?.image = NSWorkspace.shared.icon(forFile: fi.url.path)
        cell.imageView?.image?.size = NSSize(width: 16, height: 16)

        return cell
    }
}
