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

    private let imageView: NSImageView
    private let label: NSTextField
    public var showsLabel: Bool = false {
        didSet { label.isHidden = !showsLabel }
    }

    public init(icon: NSImage?, title: String, iconSize: CGFloat = 32) {
        imageView = NSImageView(frame: .zero)
        label = NSTextField(labelWithString: title)

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

    @objc private func handleClick() {
        onClick?()
    }

    public override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isHighlighted else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6)
        NSColor.controlAccentColor.withAlphaComponent(0.25).setFill()
        path.fill()
    }
}
