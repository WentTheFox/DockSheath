import Foundation
import SwiftUI
import JSON5Config

struct AppearanceSettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme", selection: $model.config.appearance.theme) {
                    Text("Auto").tag("auto")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)

                OptionalColorRow(title: "Accent Color", hex: $model.config.appearance.accentColor, fallback: .accentColor)
            }

            Section("Taskbar") {
                HStack {
                    Text("Icon size")
                    Slider(value: $model.config.appearance.iconSize, in: 16...64, step: 1)
                    Text("\(Int(model.config.appearance.iconSize)) px")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
                Toggle("Show app labels", isOn: $model.config.appearance.showAppLabels)
                Toggle("Show display number badge", isOn: $model.config.appearance.showDisplayNumber)
            }

            Section("Taskbar Colors") {
                OptionalColorRow(title: "Background", hex: $model.config.appearance.taskbarColors.background)
                OptionalColorRow(title: "Border", hex: $model.config.appearance.taskbarColors.border)
            }

            Section("Button Colors") {
                OptionalColorRow(title: "Background", hex: $model.config.appearance.buttonColors.background)
                OptionalColorRow(title: "Border", hex: $model.config.appearance.buttonColors.border)
                OptionalColorRow(title: "Text", hex: $model.config.appearance.buttonColors.text, fallback: .primary)
            }

            Section("Clock") {
                Toggle("Show a clock", isOn: $model.config.appearance.clock.enabled)
                if model.config.appearance.clock.enabled {
                    TextField("Format", text: $model.config.appearance.clock.format)
                    Text("Preview: \(clockPreview(model.config.appearance.clock.format))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Uses DateFormatter's pattern syntax, e.g. \"h:mm a\" or \"HH:mm\" — see the README for a token reference.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
    }
}

func clockPreview(_ format: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: Date())
}
