import AppKit

/// A single icon button used for both pinned apps and running-window groups
/// on the taskbar. Supports left-click, right-click (context menu), and a
/// highlighted state (e.g. for the frontmost app's group).
public final class TaskbarButton: NSView {
    public var onClick: (() -> Void)?
    public var onRightClick: (() -> Void)?

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
    public var showsLabel: Bool = false {
        didSet {
            label.isHidden = !showsLabel
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

        label.font = .systemFont(ofSize: 10)
        label.alignment = .center
        label.textColor = .labelColor
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            imageView.widthAnchor.constraint(equalToConstant: iconSize),
            imageView.heightAnchor.constraint(equalToConstant: iconSize),

            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 2),
        ])

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(clickGesture)

        toolTip = title
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The button has no width/height constraints of its own (only its
    /// subviews do), so without this it's ambiguously sized once placed in
    /// an `NSStackView` arranged-subviews list, which sets
    /// `translatesAutoresizingMaskIntoConstraints = false` on every arranged
    /// subview it manages.
    public override var intrinsicContentSize: NSSize {
        let width = iconSize + 16
        let height = iconSize + 16 + (showsLabel ? 16 : 0)
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
