import AppKit

/// Dynamically populates the Recent Files submenu when it opens.
class RecentFilesMenuDelegate: NSObject, NSMenuDelegate {

    static let shared = RecentFilesMenuDelegate()

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let recent = RecentFilesManager.shared.recentFiles

        if recent.isEmpty {
            let empty = NSMenuItem(title: "(No Recent Files)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        for (i, url) in recent.enumerated() {
            let title = url.lastPathComponent
            let item = NSMenuItem(title: title, action: #selector(openRecentFile(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            item.toolTip = url.path
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear Recent Files",
                     action: #selector(clearRecent),
                     keyEquivalent: "")
        menu.items.last?.target = self
    }

    @objc private func openRecentFile(_ sender: NSMenuItem) {
        let idx = sender.tag
        let recent = RecentFilesManager.shared.recentFiles
        guard idx >= 0, idx < recent.count else { return }
        let url = recent[idx]

        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.mainController.documentManager.openDocument(at: url)
        }
    }

    @objc private func clearRecent() {
        RecentFilesManager.shared.clear()
    }
}
