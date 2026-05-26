import AppKit

/// Simple plugin system using Swift bundles.
class PluginManager {

    static let shared = PluginManager()

    private(set) var loadedPlugins: [NotepadPlugin] = []

    var pluginsDirectory: URL {
        AppConfig.configDirectory.appendingPathComponent("Plugins")
    }

    func loadPlugins() {
        AppConfig.ensureConfigDirectory()
        let fm = FileManager.default
        try? fm.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)

        guard let items = try? fm.contentsOfDirectory(at: pluginsDirectory,
            includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }

        for url in items where url.pathExtension == "bundle" {
            guard let bundle = Bundle(url: url), bundle.load() else { continue }
            guard let principalClass = bundle.principalClass as? NotepadPlugin.Type else { continue }
            let plugin = principalClass.init()
            plugin.didLoad()
            loadedPlugins.append(plugin)
        }
    }

    func pluginMenuItems() -> [NSMenuItem] {
        return loadedPlugins.map { plugin in
            let item = NSMenuItem(title: plugin.name, action: nil, keyEquivalent: "")
            if !plugin.menuItems.isEmpty {
                let submenu = NSMenu(title: plugin.name)
                for mi in plugin.menuItems {
                    submenu.addItem(mi)
                }
                item.submenu = submenu
            }
            return item
        }
    }
}

/// Protocol for NotepadMacMac plugins.
/// Plugins are macOS bundles with a principal class conforming to this protocol.
@objc protocol NotepadPlugin: AnyObject {
    init()
    var name: String { get }
    var version: String { get }
    var menuItems: [NSMenuItem] { get }
    func didLoad()
}

/// Plugin Manager UI for viewing installed plugins.
class PluginManagerController: NSWindowController {

    private var tableView: NSTableView!

    convenience init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "Plugin Manager"
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let cv = window?.contentView else { return }

        let infoLabel = NSTextField(wrappingLabelWithString:
            "Plugins are macOS .bundle files placed in:\n\(PluginManager.shared.pluginsDirectory.path)\n\nRestart NotepadMacMac after adding plugins.")
        infoLabel.frame = NSRect(x: 16, y: cv.bounds.height - 70, width: cv.bounds.width - 32, height: 60)
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.autoresizingMask = [.width, .minYMargin]
        cv.addSubview(infoLabel)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 40, width: cv.bounds.width, height: cv.bounds.height - 115))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true

        tableView = NSTableView()
        tableView.rowHeight = 24

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Plugin"
        nameCol.width = 200
        tableView.addTableColumn(nameCol)

        let verCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("version"))
        verCol.title = "Version"
        verCol.width = 80
        tableView.addTableColumn(verCol)

        tableView.delegate = self
        tableView.dataSource = self

        scrollView.documentView = tableView
        cv.addSubview(scrollView)

        let openFolderBtn = NSButton(title: "Open Plugins Folder", target: self, action: #selector(openPluginsFolder))
        openFolderBtn.frame = NSRect(x: 16, y: 8, width: 160, height: 24)
        cv.addSubview(openFolderBtn)
    }

    @objc private func openPluginsFolder() {
        let fm = FileManager.default
        try? fm.createDirectory(at: PluginManager.shared.pluginsDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(PluginManager.shared.pluginsDirectory)
    }

    func showAndFocus() {
        tableView?.reloadData()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

extension PluginManagerController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return max(1, PluginManager.shared.loadedPlugins.count)
    }
}

extension PluginManagerController: NSTableViewDelegate {
    func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTextField(labelWithString: "")
        cell.font = NSFont.systemFont(ofSize: 12)

        if PluginManager.shared.loadedPlugins.isEmpty {
            if col?.identifier.rawValue == "name" {
                cell.stringValue = "No plugins installed"
                cell.textColor = .secondaryLabelColor
            }
        } else {
            let plugin = PluginManager.shared.loadedPlugins[row]
            switch col?.identifier.rawValue {
            case "name": cell.stringValue = plugin.name
            case "version": cell.stringValue = plugin.version; cell.textColor = .secondaryLabelColor
            default: break
            }
        }
        return cell
    }
}
