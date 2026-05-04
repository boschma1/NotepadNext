import AppKit

/// Shortcut Mapper — view and customize keyboard shortcuts.
class ShortcutMapperController: NSWindowController {

    private var tableView: NSTableView!
    private var shortcuts: [ShortcutEntry] = []
    private var filteredShortcuts: [ShortcutEntry] = []
    private var searchField: NSSearchField!

    struct ShortcutEntry {
        let category: String
        let command: String
        var keyEquivalent: String
        var modifiers: NSEvent.ModifierFlags
        let action: Selector?

        var displayShortcut: String {
            var parts: [String] = []
            if modifiers.contains(.control) { parts.append("⌃") }
            if modifiers.contains(.option) { parts.append("⌥") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            if modifiers.contains(.command) { parts.append("⌘") }
            if !keyEquivalent.isEmpty {
                parts.append(keyEquivalent.uppercased())
            }
            return parts.isEmpty ? "—" : parts.joined()
        }
    }

    convenience init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Shortcut Mapper"
        window.minSize = NSSize(width: 400, height: 300)
        self.init(window: window)
        buildShortcutList()
        setupUI()
    }

    private func buildShortcutList() {
        shortcuts = [
            // File
            ShortcutEntry(category: "File", command: "New", keyEquivalent: "n", modifiers: .command, action: nil),
            ShortcutEntry(category: "File", command: "Open", keyEquivalent: "o", modifiers: .command, action: nil),
            ShortcutEntry(category: "File", command: "Save", keyEquivalent: "s", modifiers: .command, action: nil),
            ShortcutEntry(category: "File", command: "Save As", keyEquivalent: "S", modifiers: [.command, .shift], action: nil),
            ShortcutEntry(category: "File", command: "Close Tab", keyEquivalent: "w", modifiers: .command, action: nil),
            // Edit
            ShortcutEntry(category: "Edit", command: "Undo", keyEquivalent: "z", modifiers: .command, action: nil),
            ShortcutEntry(category: "Edit", command: "Redo", keyEquivalent: "Z", modifiers: [.command, .shift], action: nil),
            ShortcutEntry(category: "Edit", command: "Cut", keyEquivalent: "x", modifiers: .command, action: nil),
            ShortcutEntry(category: "Edit", command: "Copy", keyEquivalent: "c", modifiers: .command, action: nil),
            ShortcutEntry(category: "Edit", command: "Paste", keyEquivalent: "v", modifiers: .command, action: nil),
            ShortcutEntry(category: "Edit", command: "Select All", keyEquivalent: "a", modifiers: .command, action: nil),
            ShortcutEntry(category: "Edit", command: "Duplicate Line", keyEquivalent: "d", modifiers: .command, action: nil),
            ShortcutEntry(category: "Edit", command: "Toggle Comment", keyEquivalent: "/", modifiers: .command, action: nil),
            // Search
            ShortcutEntry(category: "Search", command: "Find", keyEquivalent: "f", modifiers: .command, action: nil),
            ShortcutEntry(category: "Search", command: "Replace", keyEquivalent: "h", modifiers: .command, action: nil),
            ShortcutEntry(category: "Search", command: "Find in Files", keyEquivalent: "F", modifiers: [.command, .shift], action: nil),
            ShortcutEntry(category: "Search", command: "Go to Line", keyEquivalent: "g", modifiers: .command, action: nil),
            // View
            ShortcutEntry(category: "View", command: "Zoom In", keyEquivalent: "+", modifiers: .command, action: nil),
            ShortcutEntry(category: "View", command: "Zoom Out", keyEquivalent: "-", modifiers: .command, action: nil),
            ShortcutEntry(category: "View", command: "Reset Zoom", keyEquivalent: "0", modifiers: .command, action: nil),
            // Macro
            ShortcutEntry(category: "Macro", command: "Start/Stop Recording", keyEquivalent: "r", modifiers: [.command, .shift], action: nil),
            ShortcutEntry(category: "Macro", command: "Playback", keyEquivalent: "p", modifiers: [.command, .shift], action: nil),
            // Tools
            ShortcutEntry(category: "Tools", command: "Auto-Complete", keyEquivalent: " ", modifiers: .control, action: nil),
        ]
        filteredShortcuts = shortcuts
    }

    private func setupUI() {
        guard let cv = window?.contentView else { return }

        searchField = NSSearchField(frame: NSRect(x: 8, y: cv.bounds.height - 30, width: cv.bounds.width - 16, height: 24))
        searchField.placeholderString = "Filter shortcuts…"
        searchField.autoresizingMask = [.width, .minYMargin]
        searchField.target = self
        searchField.action = #selector(filterChanged)
        cv.addSubview(searchField)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: cv.bounds.width, height: cv.bounds.height - 38))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true

        tableView = NSTableView()
        tableView.rowHeight = 22

        let catCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cat"))
        catCol.title = "Category"
        catCol.width = 80
        tableView.addTableColumn(catCol)

        let cmdCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cmd"))
        cmdCol.title = "Command"
        cmdCol.width = 200
        tableView.addTableColumn(cmdCol)

        let keyCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("key"))
        keyCol.title = "Shortcut"
        keyCol.width = 150
        tableView.addTableColumn(keyCol)

        tableView.delegate = self
        tableView.dataSource = self

        scrollView.documentView = tableView
        cv.addSubview(scrollView)
    }

    @objc private func filterChanged() {
        let query = searchField.stringValue.lowercased()
        if query.isEmpty {
            filteredShortcuts = shortcuts
        } else {
            filteredShortcuts = shortcuts.filter {
                $0.command.lowercased().contains(query) || $0.category.lowercased().contains(query)
            }
        }
        tableView.reloadData()
    }

    func showAndFocus() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

extension ShortcutMapperController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { filteredShortcuts.count }
}

extension ShortcutMapperController: NSTableViewDelegate {
    func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        let entry = filteredShortcuts[row]
        let cell = NSTextField(labelWithString: "")
        cell.font = NSFont.systemFont(ofSize: 12)
        cell.lineBreakMode = .byTruncatingTail

        switch col?.identifier.rawValue {
        case "cat":
            cell.stringValue = entry.category
            cell.textColor = .secondaryLabelColor
        case "cmd":
            cell.stringValue = entry.command
        case "key":
            cell.stringValue = entry.displayShortcut
            cell.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        default: break
        }
        return cell
    }
}
