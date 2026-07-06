import AppKit
import JSON5Config

/// Builds and shows the Start button's Quick Launch menu — a Windows-Start-
/// menu-style list of `quickLaunchFavorites` apps, plus Settings/Quit/system
/// power actions at the bottom. Plain `NSMenuItem`s throughout (no custom
/// views, no search field, no live rebuild-while-open): once the menu no
/// longer needs to browse every installed app or filter live, there's no
/// reason to carry the custom-view-menu-item machinery that entailed (hover
/// tracking areas, deferred first-responder focus, reimplemented keyboard
/// nav) — a plain `NSMenu` already gets highlighting, keyboard nav, and
/// dismissal (outside click, another taskbar button, losing focus) for free.
public final class QuickLaunchMenuController: NSObject {
    /// Set by the caller before each `show(from:)` — the list of favorited
    /// apps, in pin order (favorites render in this order, not alphabetical).
    public var favorites: [PinnedAppEntry] = []
    /// Opens Settings to the Pinned Apps tab — forwarded as-is from
    /// `TaskbarViewController`.
    public var onManagePinnedApps: (() -> Void)?

    public func show(from view: NSView) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let titleItem = NSMenuItem(title: "Quick Launch", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        titleItem.attributedTitle = NSAttributedString(
            string: "Quick Launch",
            attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
        )
        menu.addItem(titleItem)
        menu.addItem(.separator())

        if favorites.isEmpty {
            let emptyItem = NSMenuItem(title: "No Pinned Apps", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for entry in favorites {
                let title = (entry.bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
                let item = NSMenuItem(title: title, action: #selector(launchFavoriteMenuAction(_:)), keyEquivalent: "")
                item.target = self
                item.image = NSWorkspace.shared.icon(forFile: entry.bundlePath)
                item.representedObject = entry
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Open Settings…", action: #selector(openSettingsMenuAction), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit DockSheath", action: #selector(quitMenuAction), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.addItem(.separator())

        let sleepItem = NSMenuItem(title: "Sleep", action: #selector(sleepMenuAction), keyEquivalent: "")
        sleepItem.target = self
        menu.addItem(sleepItem)

        let restartItem = NSMenuItem(title: "Restart…", action: #selector(restartMenuAction), keyEquivalent: "")
        restartItem.target = self
        menu.addItem(restartItem)

        let shutDownItem = NSMenuItem(title: "Shut Down…", action: #selector(shutDownMenuAction), keyEquivalent: "")
        shutDownItem.target = self
        menu.addItem(shutDownItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
    }

    @objc private func launchFavoriteMenuAction(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? PinnedAppEntry else { return }
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: entry.bundlePath),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    @objc private func openSettingsMenuAction() {
        onManagePinnedApps?()
    }

    @objc private func quitMenuAction() {
        NSApp.terminate(nil)
    }

    @objc private func sleepMenuAction() {
        SystemPowerAction.sleep.perform()
    }

    /// Restart/Shut Down get our own confirmation first — it isn't guaranteed
    /// that System Events' `restart`/`shut down` commands surface their own
    /// confirmation dialog on every macOS version, and losing unsaved work is
    /// exactly the kind of consequence that should never ride on an
    /// unconfirmed assumption. Sleep has no such risk (low-risk/reversible,
    /// same as the Apple menu's own unconfirmed Sleep item), so it skips this.
    @objc private func restartMenuAction() {
        confirm(
            action: .restart,
            messageText: "Restart your Mac?",
            confirmTitle: "Restart"
        )
    }

    @objc private func shutDownMenuAction() {
        confirm(
            action: .shutDown,
            messageText: "Shut down your Mac?",
            confirmTitle: "Shut Down"
        )
    }

    private func confirm(action: SystemPowerAction, messageText: String, confirmTitle: String) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = "Any unsaved work in open apps may be lost."
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        action.perform()
    }
}
