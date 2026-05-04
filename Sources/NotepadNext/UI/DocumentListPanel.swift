import AppKit

/// Document List panel showing all open files in a table.
class DocumentListPanel: NSView {

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private weak var documentManager: DocumentManager?

    weak var delegate: DocumentListDelegate?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    func attach(to manager: DocumentManager) {
        self.documentManager = manager
        reload()
    }

    func reload() {
        tableView?.reloadData()
    }

    private func setupViews() {
        scrollView = NSScrollView(frame: bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true

        tableView = NSTableView()
        tableView.rowHeight = 20
        tableView.style = .plain

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Name"
        nameCol.width = 150
        tableView.addTableColumn(nameCol)

        let pathCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        pathCol.title = "Path"
        pathCol.width = 250
        tableView.addTableColumn(pathCol)

        let langCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lang"))
        langCol.title = "Type"
        langCol.width = 80
        tableView.addTableColumn(langCol)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(rowDoubleClicked)

        scrollView.documentView = tableView
        addSubview(scrollView)
    }

    @objc private func rowDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0 else { return }
        delegate?.documentList(self, didSelectDocumentAt: row)
    }
}

protocol DocumentListDelegate: AnyObject {
    func documentList(_ panel: DocumentListPanel, didSelectDocumentAt index: Int)
}

extension DocumentListPanel: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return documentManager?.documents.count ?? 0
    }
}

extension DocumentListPanel: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let doc = documentManager?.documents[safe: row] else { return nil }
        let cell = NSTextField(labelWithString: "")
        cell.lineBreakMode = .byTruncatingTail
        cell.font = NSFont.systemFont(ofSize: 12)

        switch tableColumn?.identifier.rawValue {
        case "name":
            cell.stringValue = doc.displayTitle
        case "path":
            cell.stringValue = doc.fileURL?.path ?? "(unsaved)"
            cell.textColor = .secondaryLabelColor
        case "lang":
            cell.stringValue = doc.language
            cell.textColor = .secondaryLabelColor
        default: break
        }
        return cell
    }
}
