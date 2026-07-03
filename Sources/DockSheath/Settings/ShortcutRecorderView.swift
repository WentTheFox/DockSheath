import AppKit
import SwiftUI
import JSON5Config

/// A focusable `NSView` that, while recording, captures the next key event
/// and turns it into a `HotKeyBinding` — the raw material for a shortcut
/// recorder control. `NSEvent.keyCode` and Carbon's `RegisterEventHotKey`
/// (see `GlobalHotKey`) share the same virtual-keycode numbering, so the
/// captured code can be stored directly with no translation.
fileprivate final class KeyCaptureNSView: NSView {
    var onCapture: ((HotKeyBinding) -> Void)?
    var isRecording = false {
        didSet {
            guard isRecording, let window else { return }
            window.makeFirstResponder(self)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        var modifiers: [String] = []
        let flags = event.modifierFlags
        if flags.contains(.control) { modifiers.append("control") }
        if flags.contains(.option) { modifiers.append("option") }
        if flags.contains(.shift) { modifiers.append("shift") }
        if flags.contains(.command) { modifiers.append("command") }

        // Require at least one modifier — an unmodified global hotkey would
        // swallow every ordinary keystroke system-wide.
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return
        }

        onCapture?(HotKeyBinding(keyCode: UInt32(event.keyCode), modifiers: modifiers))
    }
}

/// SwiftUI wrapper around `KeyCaptureNSView`.
struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCapture: (HotKeyBinding) -> Void

    fileprivate func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onCapture = { binding in
            onCapture(binding)
            isRecording = false
        }
        return view
    }

    fileprivate func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.isRecording = isRecording
    }
}
