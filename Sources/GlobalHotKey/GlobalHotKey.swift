import Carbon.HIToolbox
import JSON5Config

/// Wraps the Carbon `RegisterEventHotKey` API to provide a single systemwide
/// keyboard shortcut (used for the taskbar show/hide toggle). Carbon's hotkey
/// API is still the standard, fully-functional mechanism for this on modern
/// macOS and doesn't require the broader event-tap surface of
/// `NSEvent.addGlobalMonitorForEvents`.
public final class GlobalHotKey {
    public typealias Handler = () -> Void

    private static var handlers: [UInt32: Handler] = [:]
    private static var nextID: UInt32 = 1
    private static var eventHandlerInstalled = false

    private let id: UInt32
    private var hotKeyRef: EventHotKeyRef?

    public init?(binding: HotKeyBinding, handler: @escaping Handler) {
        Self.installEventHandlerIfNeeded()

        let assignedID = Self.nextID
        Self.nextID += 1

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: assignedID)
        let status = RegisterEventHotKey(
            binding.keyCode,
            Self.carbonModifiers(from: binding.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let registeredRef = ref else {
            return nil
        }

        id = assignedID
        hotKeyRef = registeredRef
        Self.handlers[assignedID] = handler
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        Self.handlers[id] = nil
    }

    private static let signature: OSType = fourCharCode("DKSH")

    private static func installEventHandlerIfNeeded() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return status }
            GlobalHotKey.handlers[hotKeyID.id]?()
            return noErr
        }, 1, &eventType, nil, nil)
    }

    private static func carbonModifiers(from modifiers: [String]) -> UInt32 {
        var flags: UInt32 = 0
        for modifier in modifiers {
            switch modifier.lowercased() {
            case "command", "cmd":
                flags |= UInt32(cmdKey)
            case "option", "alt":
                flags |= UInt32(optionKey)
            case "control", "ctrl":
                flags |= UInt32(controlKey)
            case "shift":
                flags |= UInt32(shiftKey)
            default:
                break
            }
        }
        return flags
    }
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for scalar in string.unicodeScalars {
        result = (result << 8) + OSType(scalar.value & 0xFF)
    }
    return result
}
