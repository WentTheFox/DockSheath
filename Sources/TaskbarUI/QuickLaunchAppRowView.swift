import AppKit

/// A single row in the Quick Launch menu's app list: icon + name + a trailing
/// star button toggling whether the app is a `quickLaunchFavorites` pin.
///
/// Installed as an `NSMenuItem`'s custom `view`, which means `NSMenu` no
/// longer draws its own hover highlight or forwards clicks to an
/// action/target for this item — both are handled here instead (see
/// `mouseEntered`/`mouseDown` and `draw(_:)`), mirroring the pattern
/// `TaskbarButton` already uses elsewhere in this target.
public final class QuickLaunchAppRowView: NSView {
    public let app: InstalledApp

    public var onLaunch: (() -> Void)?
    public var onToggleFavorite: (() -> Void)?

    public var isFavorite: Bool = false {
        didSet {
            guard oldValue != isFavorite else { return }
            updateStarImage()
        }
    }

    /// Mouse hovering over the row.
    private var isHovered: Bool = false {
        didSet { needsDisplay = true }
    }
    /// Currently selected via the search field's arrow-key navigation —
    /// tracked separately from `isHovered` so moving the mouse away after
    /// navigating with the keyboard doesn't clear the keyboard's own
    /// selection highlight.
    public var isKeyboardSelected: Bool = false {
        didSet { needsDisplay = true }
    }

    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let starButton = NSButton()
    private var trackingArea: NSTrackingArea?

    public init(app: InstalledApp, width: CGFloat, height: CGFloat) {
        self.app = app
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))

        iconView.image = app.icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        nameLabel.stringValue = app.name
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        starButton.isBordered = false
        starButton.bezelStyle = .regularSquare
        starButton.imagePosition = .imageOnly
        starButton.target = self
        starButton.action = #selector(starClicked)
        starButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(starButton)
        updateStarImage()

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            starButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            starButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            starButton.widthAnchor.constraint(equalToConstant: 18),
            starButton.heightAnchor.constraint(equalToConstant: 18),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: starButton.leadingAnchor, constant: -6),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        toolTip = app.name
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateStarImage() {
        let symbolName = isFavorite ? "star.fill" : "star"
        let description = isFavorite ? "Remove from Quick Launch Favorites" : "Add to Quick Launch Favorites"
        starButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        starButton.contentTintColor = isFavorite ? .controlAccentColor : .tertiaryLabelColor
        starButton.toolTip = description
    }

    @objc private func starClicked() {
        onToggleFavorite?()
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    public override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    /// Only reached for clicks outside `starButton`'s own frame — a real
    /// `NSControl` subview claims its own `mouseDown` before it would ever
    /// reach this override, so no `hitTest` override is needed here (unlike
    /// `TaskbarButton`, whose subviews are non-interactive).
    public override func mouseDown(with event: NSEvent) {
        onLaunch?()
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isHovered || isKeyboardSelected else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 4, yRadius: 4)
        NSColor.controlAccentColor.withAlphaComponent(isHovered ? 0.2 : 0.12).setFill()
        path.fill()
    }
}
