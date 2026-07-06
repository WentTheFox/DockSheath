import AppKit

/// The Quick Launch menu's top row: a native `NSSearchField`, installed as an
/// `NSMenuItem`'s custom `view`. Purely presentational — all delegate/filter
/// logic lives on `QuickLaunchMenuController`, which sets itself as
/// `searchField.delegate`.
///
/// Deliberately a plain AppKit control rather than a SwiftUI view hosted via
/// `NSHostingView`, unlike the deleted `QuickLaunchSearchView` this replaces
/// — that one lived in a `.nonactivatingPanel` `NSPanel`, where the panel
/// itself (not this field) never reliably received the click needed to focus
/// it. A native field inside a real `NSMenu` doesn't have that problem, since
/// `NSMenu` owns key window/first-responder handling itself.
public final class QuickLaunchSearchFieldItemView: NSView {
    public let searchField = NSSearchField()

    public init(width: CGFloat, height: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))

        searchField.placeholderString = "Search apps…"
        searchField.font = .systemFont(ofSize: 13)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchField)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
