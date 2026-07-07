import SwiftUI
import JSON5Config

struct HotkeySettingsView: View {
    @ObservedObject var model: SettingsModel
    @State private var isRecording = false

    var body: some View {
        ScrollView {
            Form {
                Section {
                    Text("Toggles the taskbar's visibility, revealing the real Dock underneath.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Show/Hide Taskbar")
                        Spacer()

                        ZStack {
                            // Captures the next key event while recording; sized
                            // to match the button so it's invisible otherwise.
                            ShortcutRecorderView(isRecording: $isRecording) { binding in
                                model.config.hotkeys.toggleVisibility = binding
                            }
                            .frame(width: 140, height: 24)

                            Button(action: { isRecording.toggle() }) {
                                Text(buttonLabel)
                                    .frame(minWidth: 120)
                            }
                            .allowsHitTesting(!isRecording)
                        }

                        if model.config.hotkeys.toggleVisibility != nil {
                            Button("Clear") {
                                model.config.hotkeys.toggleVisibility = nil
                                isRecording = false
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private var buttonLabel: String {
        if isRecording {
            return "Press a key combination…"
        }
        if let binding = model.config.hotkeys.toggleVisibility {
            return KeyCodeNames.displayString(for: binding)
        }
        return "Record Shortcut…"
    }
}
