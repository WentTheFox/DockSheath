import AppKit
import SwiftUI
import JSON5Config
import TaskbarUI

/// Overrides applied to every taskbar except the one on the real Dock's
/// screen (see `behavior.showOnAllDisplays`). Each row is unchecked by
/// default, meaning "inherit the corresponding value from the Appearance/
/// General tabs" — matching `AppearanceConfig.applying(_:)`/
/// `TaskbarAppearanceConfig.applying(_:)`.
struct SecondaryDisplaySettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Text("Anything left unchecked here inherits the matching setting from the General/Appearance tabs.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Taskbar") {
                OverrideRow(
                    title: "Override taskbar thickness",
                    value: $model.config.secondaryDisplay.taskbar.sizeOverride,
                    makeDefault: { model.config.taskbar.sizeOverride ?? 60 }
                ) { binding in
                    HStack {
                        Slider(value: binding, in: 20...120, step: 1)
                        Text("\(Int(binding.wrappedValue)) px")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }

            Section("Appearance") {
                OverrideRow(
                    title: "Override theme",
                    value: $model.config.secondaryDisplay.appearance.theme,
                    makeDefault: { model.config.appearance.theme }
                ) { binding in
                    Picker("Theme", selection: binding) {
                        Text("Auto").tag("auto")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                OverrideRow(
                    title: "Override accent color",
                    value: $model.config.secondaryDisplay.appearance.accentColor,
                    makeDefault: { model.config.appearance.accentColor ?? "#0A84FF" }
                ) { binding in
                    ColorPicker(
                        "Accent Color",
                        selection: Binding(
                            get: { NSColor(hexString: binding.wrappedValue).map { Color($0) } ?? .accentColor },
                            set: { binding.wrappedValue = NSColor($0).hexString }
                        ),
                        supportsOpacity: true
                    )
                }

                OverrideRow(
                    title: "Override icon size",
                    value: $model.config.secondaryDisplay.appearance.iconSize,
                    makeDefault: { model.config.appearance.iconSize }
                ) { binding in
                    HStack {
                        Slider(value: binding, in: 16...64, step: 1)
                        Text("\(Int(binding.wrappedValue)) px")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }

                OverrideRow(
                    title: "Override \"show app labels\"",
                    value: $model.config.secondaryDisplay.appearance.showAppLabels,
                    makeDefault: { model.config.appearance.showAppLabels }
                ) { binding in
                    Toggle("Show app labels", isOn: binding)
                }

                OverrideRow(
                    title: "Override display number badge",
                    value: $model.config.secondaryDisplay.appearance.showDisplayNumber,
                    makeDefault: { model.config.appearance.showDisplayNumber }
                ) { binding in
                    Toggle("Show display number badge", isOn: binding)
                }
            }

            Section("Colors") {
                OverrideRow(
                    title: "Override taskbar colors",
                    value: $model.config.secondaryDisplay.appearance.taskbarColors,
                    makeDefault: { model.config.appearance.taskbarColors }
                ) { binding in
                    OptionalColorRow(title: "Background", hex: binding.background)
                    OptionalColorRow(title: "Border", hex: binding.border)
                }

                OverrideRow(
                    title: "Override button colors",
                    value: $model.config.secondaryDisplay.appearance.buttonColors,
                    makeDefault: { model.config.appearance.buttonColors }
                ) { binding in
                    OptionalColorRow(title: "Background", hex: binding.background)
                    OptionalColorRow(title: "Border", hex: binding.border)
                    OptionalColorRow(title: "Text", hex: binding.text, fallback: .primary)
                }
            }

            Section("Clock") {
                OverrideRow(
                    title: "Override clock",
                    value: $model.config.secondaryDisplay.appearance.clock,
                    makeDefault: { model.config.appearance.clock }
                ) { binding in
                    Toggle("Show a clock", isOn: binding.enabled)
                    if binding.enabled.wrappedValue {
                        TextField("Format", text: binding.format)
                        Text("Preview: \(clockPreview(binding.format.wrappedValue))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
    }
}
