import AppKit
import JSON5Config

/// The taskbar strip of pinned "quick launch" apps, backed by
/// `TaskbarConfig.pinnedApps`. Visually separate from the running-windows
/// strip, matching uBar's model of two distinct zones.
public final class PinnedAppsStripView: NSView {
    private let stackView = NSStackView()
    public var pinnedApps: [PinnedAppEntry] = [] {
        didSet { rebuildButtons() }
    }
    public var onUnpin: ((PinnedAppEntry) -> Void)?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        stackView.orientation = .horizontal
        stackView.spacing = 4
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func rebuildButtons() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for entry in pinnedApps {
            let icon = NSWorkspace.shared.icon(forFile: entry.bundlePath)
            let name = (entry.bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
            let button = TaskbarButton(icon: icon, title: name)
            button.onClick = { [weak self] in self?.launch(entry) }
            button.onRightClick = { [weak self] in self?.showContextMenu(for: entry, from: button) }
            stackView.addArrangedSubview(button)
        }
    }

    private func launch(_ entry: PinnedAppEntry) {
        let url = URL(fileURLWithPath: entry.bundlePath)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func showContextMenu(for entry: PinnedAppEntry, from view: NSView) {
        let menu = NSMenu()
        let item = menu.addItem(withTitle: "Unpin from Taskbar", action: #selector(unpinMenuAction(_:)), keyEquivalent: "")
        item.representedObject = entry
        item.target = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
    }

    @objc private func unpinMenuAction(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? PinnedAppEntry else { return }
        onUnpin?(entry)
    }
}
