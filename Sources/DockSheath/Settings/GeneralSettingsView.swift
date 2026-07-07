import SwiftUI
import JSON5Config

struct GeneralSettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            Form {
                Section("Behavior") {
                    Toggle("Show a taskbar on every connected display", isOn: $model.config.behavior.showOnAllDisplays)
                    Toggle("Group windows by app", isOn: $model.config.behavior.groupWindowsByApp)

                    HStack {
                        Text("Refresh interval")
                        Slider(
                            value: Binding(
                                get: { Double(model.config.behavior.refreshIntervalMs) },
                                set: { model.config.behavior.refreshIntervalMs = Int($0) }
                            ),
                            in: 500...5000,
                            step: 100
                        )
                        Text("\(model.config.behavior.refreshIntervalMs) ms")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                }
            }
            .padding(20)
        }
    }
}
