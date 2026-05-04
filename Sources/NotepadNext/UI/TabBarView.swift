import AppKit

protocol TabBarViewDelegate: AnyObject {
    func tabBarView(_ tabBar: TabBarView, didSelectTabAt index: Int)
    func tabBarView(_ tabBar: TabBarView, didCloseTabAt index: Int)
    func tabBarViewDidRequestNewTab(_ tabBar: TabBarView)
}

/// Custom tab bar that mimics Notepad++ style tabs.
class TabBarView: NSView {

    struct Tab {
        let id: UUID
        var title: String
        var isModified: Bool
    }

    weak var delegate: TabBarViewDelegate?

    private(set) var tabs: [Tab] = []
    private(set) var selectedIndex: Int = -1

    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var addButton: NSButton!

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

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false

        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stackView

        addButton = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab")!,
                             target: self,
                             action: #selector(addTabClicked))
        addButton.bezelStyle = .accessoryBarAction
        addButton.isBordered = false
        addButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        addSubview(addButton)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -4),

            addButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 24),
            addButton.heightAnchor.constraint(equalToConstant: 24),

            heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    // MARK: - Public API

    func addTab(_ tab: Tab) {
        tabs.append(tab)
        let button = createTabButton(for: tab, at: tabs.count - 1)
        stackView.addArrangedSubview(button)
        selectTab(at: tabs.count - 1)
    }

    func removeTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        tabs.remove(at: index)
        stackView.arrangedSubviews[index].removeFromSuperview()
        refreshAllTabs()
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        selectedIndex = index
        refreshAllTabs()
    }

    func updateTab(at index: Int, title: String, isModified: Bool) {
        guard index >= 0, index < tabs.count else { return }
        tabs[index].title = title
        tabs[index].isModified = isModified
        refreshAllTabs()
    }

    // MARK: - Private

    private func createTabButton(for tab: Tab, at index: Int) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleButton = NSButton(title: tab.title, target: self, action: #selector(tabClicked(_:)))
        titleButton.bezelStyle = .accessoryBarAction
        titleButton.tag = index
        titleButton.translatesAutoresizingMaskIntoConstraints = false
        titleButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let closeButton = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")!,
                                   target: self,
                                   action: #selector(closeTabClicked(_:)))
        closeButton.bezelStyle = .accessoryBarAction
        closeButton.isBordered = false
        closeButton.tag = index
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setContentHuggingPriority(.required, for: .horizontal)

        container.addSubview(titleButton)
        container.addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            titleButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            closeButton.leadingAnchor.constraint(equalTo: titleButton.trailingAnchor, constant: 2),
            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 16),
            closeButton.heightAnchor.constraint(equalToConstant: 16),

            container.heightAnchor.constraint(equalTo: heightAnchor),
        ])

        return container
    }

    private func refreshAllTabs() {
        // Remove all and rebuild (simple approach)
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, tab) in tabs.enumerated() {
            let button = createTabButton(for: tab, at: i)
            if i == selectedIndex {
                button.wantsLayer = true
                button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            }
            stackView.addArrangedSubview(button)
        }
    }

    // MARK: - Actions

    @objc private func tabClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0, index < tabs.count else { return }
        delegate?.tabBarView(self, didSelectTabAt: index)
    }

    @objc private func closeTabClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0, index < tabs.count else { return }
        delegate?.tabBarView(self, didCloseTabAt: index)
    }

    @objc private func addTabClicked() {
        delegate?.tabBarViewDidRequestNewTab(self)
    }
}
