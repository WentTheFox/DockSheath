import AppKit
import JSON5Config

/// Builds and drives the Start button's Quick Launch menu: every installed
/// app (via `InstalledAppsIndex`), live-filterable by a search field, with
/// `quickLaunchFavorites` entries pinned to the top.
///
/// Stays on a real `NSMenu` rather than a custom panel window specifically so
/// dismissal (outside click, another taskbar button, losing focus) is native
/// `NSMenu` behavior rather than something this class has to implement
/// itself — the deleted `QuickLaunchWindowController` this replaces never
/// dismissed on any of those, since a bespoke `.nonactivatingPanel` gets none
/// of that for free.
public final class QuickLaunchMenuController: NSObject {
    /// Row width for both the search field and every app row, so everything
    /// lines up in a single fixed-width column regardless of app name length.
    private static let rowWidth: CGFloat = 280
    private static let rowHeight: CGFloat = 26
    private static let searchRowHeight: CGFloat = 28

    /// Set by the caller before each `show(from:)` — the list of favorited
    /// apps, in pin order (favorites render in this order, not alphabetical).
    public var favorites: [PinnedAppEntry] = []
    public var onFavoritesChanged: (([PinnedAppEntry]) -> Void)?
    /// Passthrough for the trailing "Manage Pinned Apps…" item — unrelated to
    /// favorites, forwarded as-is from `TaskbarViewController`.
    public var onManagePinnedApps: (() -> Void)?

    private let searchFieldItemView = QuickLaunchSearchFieldItemView(width: rowWidth, height: searchRowHeight)
    private var allApps: [InstalledApp] = []
    private var query: String = ""
    private var menu: NSMenu?
    /// How many items currently sit between the fixed search-field item (0)
    /// and the fixed trailing separator + "Manage Pinned Apps…" item, so
    /// `rebuildRows()` knows exactly which range to replace.
    private var dynamicItemCount: Int = 0
    private var rowViews: [QuickLaunchAppRowView] = []
    private var selectedIndex: Int = -1

    public override init() {
        super.init()
        searchFieldItemView.searchField.delegate = self
    }

    public func show(from view: NSView) {
        allApps = InstalledAppsIndex.scan()
        query = ""
        searchFieldItemView.searchField.stringValue = ""
        selectedIndex = -1

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        self.menu = menu

        let searchItem = NSMenuItem()
        searchItem.view = searchFieldItemView
        menu.addItem(searchItem)

        dynamicItemCount = 0
        rebuildRows()

        menu.addItem(.separator())
        let manageItem = NSMenuItem(title: "Manage Pinned Apps…", action: #selector(manageAction), keyEquivalent: "")
        manageItem.target = self
        menu.addItem(manageItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
    }

    @objc private func manageAction() {
        onManagePinnedApps?()
    }

    // MARK: - Row building / filtering

    /// Pure section-filtering logic, kept free of any `NSMenu`/AppKit runtime
    /// dependency so it can be unit tested directly.
    static func buildSections(
        allApps: [InstalledApp],
        favorites: [PinnedAppEntry],
        query: String
    ) -> (favorites: [InstalledApp], others: [InstalledApp]) {
        // Preserves `favorites`' own order (pin order) rather than the
        // alphabetical order `allApps` is scanned in. A favorite that no
        // longer resolves to an installed app (deleted/moved since it was
        // pinned) is simply omitted here — `compactMap` drops it from this
        // listing without touching the persisted `favorites` array itself.
        let favoriteApps: [InstalledApp] = favorites.compactMap { entry in
            allApps.first { matches($0, entry) }
        }
        let favoriteIDs = Set(favoriteApps.map(\.id))
        let otherApps = allApps.filter { !favoriteIDs.contains($0.id) }

        return (
            FuzzySearch.filterAndSort(favoriteApps, query: query, text: \.name),
            FuzzySearch.filterAndSort(otherApps, query: query, text: \.name)
        )
    }

    private static func matches(_ app: InstalledApp, _ entry: PinnedAppEntry) -> Bool {
        if let entryID = entry.bundleIdentifier, let appID = app.bundleIdentifier {
            return entryID == appID
        }
        return entry.bundlePath == app.bundlePath
    }

    private func rebuildRows() {
        guard let menu else { return }
        for _ in 0..<dynamicItemCount {
            menu.removeItem(at: 1)
        }
        rowViews.removeAll()

        let sections = Self.buildSections(allApps: allApps, favorites: favorites, query: query)
        var newItems: [NSMenuItem] = []

        if sections.favorites.isEmpty && sections.others.isEmpty {
            if !query.isEmpty {
                let emptyItem = NSMenuItem(title: "No Matching Apps", action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                newItems.append(emptyItem)
            }
        } else {
            for app in sections.favorites {
                newItems.append(makeRowItem(for: app, isFavorite: true))
            }
            if !sections.favorites.isEmpty && !sections.others.isEmpty {
                newItems.append(.separator())
            }
            for app in sections.others {
                newItems.append(makeRowItem(for: app, isFavorite: false))
            }
        }

        for (offset, item) in newItems.enumerated() {
            menu.insertItem(item, at: 1 + offset)
        }
        dynamicItemCount = newItems.count

        selectedIndex = rowViews.isEmpty ? -1 : 0
        updateSelectionHighlight()
    }

    private func makeRowItem(for app: InstalledApp, isFavorite: Bool) -> NSMenuItem {
        let row = QuickLaunchAppRowView(app: app, width: Self.rowWidth, height: Self.rowHeight)
        row.isFavorite = isFavorite
        row.onLaunch = { [weak self] in self?.launch(app) }
        row.onToggleFavorite = { [weak self] in self?.toggleFavorite(for: app) }
        rowViews.append(row)

        let item = NSMenuItem()
        item.view = row
        item.title = app.name
        return item
    }

    private func toggleFavorite(for app: InstalledApp) {
        if let index = favorites.firstIndex(where: { Self.matches(app, $0) }) {
            favorites.remove(at: index)
        } else {
            favorites.append(PinnedAppEntry(bundlePath: app.bundlePath, bundleIdentifier: app.bundleIdentifier))
        }
        onFavoritesChanged?(favorites)
        rebuildRows()
    }

    private func launch(_ app: InstalledApp) {
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: app.bundlePath),
            configuration: NSWorkspace.OpenConfiguration()
        )
        menu?.cancelTracking()
    }

    // MARK: - Keyboard navigation

    private func moveSelection(by delta: Int) {
        guard !rowViews.isEmpty else { return }
        let newIndex = min(max(selectedIndex + delta, 0), rowViews.count - 1)
        guard newIndex != selectedIndex else { return }
        selectedIndex = newIndex
        updateSelectionHighlight()
    }

    private func updateSelectionHighlight() {
        for (index, row) in rowViews.enumerated() {
            row.isKeyboardSelected = index == selectedIndex
        }
    }

    private func launchSelected() {
        guard rowViews.indices.contains(selectedIndex) else { return }
        launch(rowViews[selectedIndex].app)
    }
}

extension QuickLaunchMenuController: NSSearchFieldDelegate {
    public func controlTextDidChange(_ obj: Notification) {
        query = searchFieldItemView.searchField.stringValue
        rebuildRows()
    }

    /// `NSMenu`'s own arrow-key/Return handling stops working once a subview
    /// text field becomes first responder (see `menuWillOpen(_:)` below), so
    /// row navigation is reimplemented here instead.
    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            launchSelected()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            menu?.cancelTracking()
            return true
        default:
            return false
        }
    }
}

extension QuickLaunchMenuController: NSMenuDelegate {
    /// The menu's backing window isn't guaranteed to be ready for
    /// `makeFirstResponder` synchronously inside `menuWillOpen(_:)` — this is
    /// the specific focus problem that needs solving for a menu-hosted search
    /// field (a different problem than the one that sank the old
    /// nonactivating-panel approach). Deferring one runloop tick is the
    /// established workaround: a main-queue GCD block still drains during
    /// `NSMenu`'s tracking loop, unlike `Timer`/`perform(_:afterDelay:)`,
    /// which would need explicit `.common` run loop mode registration.
    public func menuWillOpen(_ menu: NSMenu) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.searchFieldItemView.searchField.window else { return }
            window.makeFirstResponder(self.searchFieldItemView.searchField)
        }
    }
}
