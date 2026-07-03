import AppKit

/// A single button used for the Start button, pinned apps, and
/// running-window groups on the taskbar. Supports left-click, right-click
/// (context menu), and a highlighted state (e.g. for the frontmost app's
/// group).
///
/// Icon-only when `showsLabel` is false — a centered square icon, matching
/// the classic Dock-icon look. Icon-and-title in a single row when true, so
/// window titles read left-to-right next to their icon instead of wrapping
/// onto a second line underneath it. The button's width is capped at
/// `maxWidth` regardless of title length — long titles truncate with an
/// ellipsis rather than ballooning the button (the full title is still
/// available via `toolTip`, which callers can set to something richer, e.g.
/// listing every window's title for a multi-window app group).
public final class TaskbarButton: NSView {
    public var onClick: (() -> Void)?
    public var onRightClick: (() -> Void)?

    /// The widest a labeled button is allowed to grow before its title
    /// truncates instead.
    public static let maxWidth: CGFloat = 160

    public var isHighlighted: Bool = false {
        didSet { needsDisplay = true }
    }

    /// `nil` means "no persistent fill" — the button stays transparent
    /// except for the highlight tint, matching the default system look.
    public var backgroundColor: NSColor? {
        didSet { needsDisplay = true }
    }
    /// `nil` means "no border drawn".
    public var borderColor: NSColor? {
        didSet { needsDisplay = true }
    }
    public var highlightColor: NSColor = .controlAccentColor {
        didSet { needsDisplay = true }
    }
    public var textColor: NSColor = .labelColor {
        didSet { label.textColor = textColor }
    }

    private let imageView: NSImageView
    private let label: NSTextField
    private let iconSize: CGFloat
    private var iconOnlyConstraints: [NSLayoutConstraint] = []
    private var iconWithLabelConstraints: [NSLayoutConstraint] = []

    public var showsLabel: Bool = false {
        didSet {
            guard oldValue != showsLabel else { return }
            label.isHidden = !showsLabel
            NSLayoutConstraint.deactivate(showsLabel ? iconOnlyConstraints : iconWithLabelConstraints)
            NSLayoutConstraint.activate(showsLabel ? iconWithLabelConstraints : iconOnlyConstraints)
            invalidateIntrinsicContentSize()
        }
    }

    public init(icon: NSImage?, title: String, iconSize: CGFloat = 32) {
        imageView = NSImageView(frame: .zero)
        label = NSTextField(labelWithString: title)
        self.iconSize = iconSize

        super.init(frame: NSRect(x: 0, y: 0, width: iconSize + 16, height: iconSize + 16))

        imageView.image = icon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        label.font = .systemFont(ofSize: 11)
        label.alignment = .left
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: iconSize),
            imageView.heightAnchor.constraint(equalToConstant: iconSize),
            widthAnchor.constraint(lessThanOrEqualToConstant: Self.maxWidth),
        ])

        iconOnlyConstraints = [
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ]

        iconWithLabelConstraints = [
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ]

        NSLayoutConstraint.activate(iconOnlyConstraints)

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(clickGesture)

        toolTip = title
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The button has no width/height constraints of its own beyond the
    /// `maxWidth` cap (only its subviews do), so without this it's
    /// ambiguously sized once placed in an `NSStackView` arranged-subviews
    /// list, which sets `translatesAutoresizingMaskIntoConstraints = false`
    /// on every arranged subview it manages.
    public override var intrinsicContentSize: NSSize {
        guard showsLabel else {
            return NSSize(width: iconSize + 16, height: iconSize + 16)
        }
        // 6 (leading) + iconSize + 6 (icon-label gap) + text + 8 (trailing).
        let naturalWidth = iconSize + 20 + label.attributedStringValue.size().width
        let width = min(naturalWidth, Self.maxWidth)
        let height = max(iconSize + 8, 28)
        return NSSize(width: width, height: height)
    }

    @objc private func handleClick() {
        onClick?()
    }

    public override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    /// Applies a resolved `TaskbarTheme`'s button colors. `nil` fields in the
    /// theme reset this button back to its transparent, system-colored
    /// default rather than leaving a stale override in place.
    public func applyTheme(_ theme: TaskbarTheme) {
        backgroundColor = theme.buttonBackground
        borderColor = theme.buttonBorder
        textColor = theme.buttonText ?? .labelColor
        highlightColor = theme.buttonHighlight
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6)
        if let backgroundColor {
            backgroundColor.setFill()
            path.fill()
        }
        if isHighlighted {
            highlightColor.withAlphaComponent(0.25).setFill()
            path.fill()
        }
        if let borderColor {
            path.lineWidth = 1
            borderColor.setStroke()
            path.stroke()
        }
    }
}
