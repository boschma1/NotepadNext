import AppKit

protocol TabBarViewDelegate: AnyObject {
    func tabBarView(_ tabBar: TabBarView, didSelectTabAt index: Int)
    func tabBarView(_ tabBar: TabBarView, didCloseTabAt index: Int)
    func tabBarViewDidRequestNewTab(_ tabBar: TabBarView)
}

class TabBarView: NSView {

    struct Tab {
        let id: UUID
        var title: String
        var isModified: Bool
    }

    weak var delegate: TabBarViewDelegate?
    private(set) var tabs: [Tab] = []
    private(set) var selectedIndex: Int = -1

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    func addTab(_ tab: Tab) {
        tabs.append(tab)
        selectTab(at: tabs.count - 1)
    }

    func removeTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        tabs.remove(at: index)
        rebuildButtons()
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        selectedIndex = index
        rebuildButtons()
    }

    func updateTab(at index: Int, title: String, isModified: Bool) {
        guard index >= 0, index < tabs.count else { return }
        tabs[index].title = title
        tabs[index].isModified = isModified
        rebuildButtons()
    }

    private func rebuildButtons() {
        subviews.forEach { $0.removeFromSuperview() }

        var x: CGFloat = 4
        for (i, tab) in tabs.enumerated() {
            let btn = NSButton(title: tab.title, target: self, action: #selector(tabClicked(_:)))
            btn.tag = i
            btn.bezelStyle = .accessoryBarAction
            btn.sizeToFit()
            btn.frame = NSRect(x: x, y: 2, width: btn.frame.width + 20, height: bounds.height - 4)
            if i == selectedIndex {
                btn.wantsLayer = true
                btn.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
                btn.layer?.cornerRadius = 4
            }
            addSubview(btn)

            let closeBtn = NSButton(title: "✕", target: self, action: #selector(closeClicked(_:)))
            closeBtn.tag = i
            closeBtn.bezelStyle = .accessoryBarAction
            closeBtn.isBordered = false
            closeBtn.font = NSFont.systemFont(ofSize: 10)
            closeBtn.frame = NSRect(x: btn.frame.maxX - 16, y: 6, width: 16, height: 16)
            addSubview(closeBtn)

            x = btn.frame.maxX + 2
        }

        let addBtn = NSButton(title: "+", target: self, action: #selector(addClicked))
        addBtn.bezelStyle = .accessoryBarAction
        addBtn.isBordered = false
        addBtn.font = NSFont.systemFont(ofSize: 16)
        addBtn.frame = NSRect(x: x + 4, y: 2, width: 26, height: bounds.height - 4)
        addSubview(addBtn)
    }

    @objc private func tabClicked(_ sender: NSButton) {
        delegate?.tabBarView(self, didSelectTabAt: sender.tag)
    }

    @objc private func closeClicked(_ sender: NSButton) {
        delegate?.tabBarView(self, didCloseTabAt: sender.tag)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        // Find which tab was right-clicked
        for (i, _) in tabs.enumerated() {
            for sub in subviews {
                if let btn = sub as? NSButton, btn.tag == i, btn.frame.contains(point) {
                    let menu = NSMenu()
                    let closeItem = NSMenuItem(title: "Close", action: #selector(contextClose(_:)), keyEquivalent: "")
                    closeItem.tag = i
                    closeItem.target = self
                    menu.addItem(closeItem)

                    let closeOthers = NSMenuItem(title: "Close All But This", action: #selector(contextCloseOthers(_:)), keyEquivalent: "")
                    closeOthers.tag = i
                    closeOthers.target = self
                    menu.addItem(closeOthers)

                    menu.addItem(.separator())

                    let copyPath = NSMenuItem(title: "Copy File Path", action: #selector(contextCopyPath(_:)), keyEquivalent: "")
                    copyPath.tag = i
                    copyPath.target = self
                    menu.addItem(copyPath)

                    return menu
                }
            }
        }
        return nil
    }

    @objc private func contextClose(_ sender: NSMenuItem) {
        delegate?.tabBarView(self, didCloseTabAt: sender.tag)
    }

    @objc private func contextCloseOthers(_ sender: NSMenuItem) {
        let keep = sender.tag
        for i in stride(from: tabs.count - 1, through: 0, by: -1) {
            if i != keep { delegate?.tabBarView(self, didCloseTabAt: i) }
        }
    }

    @objc private func contextCopyPath(_ sender: NSMenuItem) {
        // Delegate will handle this via notification
        NotificationCenter.default.post(name: .init("CopyTabPath"), object: sender.tag)
    }

    @objc private func addClicked() {
        delegate?.tabBarViewDidRequestNewTab(self)
    }
}
