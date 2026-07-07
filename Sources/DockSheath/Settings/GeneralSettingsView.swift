import AppKit
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

                Section("Updates") {
                    Toggle("Check for updates automatically", isOn: $model.config.updateCheck.checkForUpdates)

                    HStack {
                        Text("Repository path")
                        TextField(
                            "Not set",
                            text: Binding(
                                get: { model.config.updateCheck.repositoryPath ?? "" },
                                set: { model.config.updateCheck.repositoryPath = $0.isEmpty ? nil : $0 }
                            )
                        )
                        Button("Choose…") { chooseRepositoryPath() }
                    }

                    Button("Check for Updates Now") {
                        model.onCheckForUpdatesNow?()
                    }
                    .disabled((model.config.updateCheck.repositoryPath ?? "").isEmpty)
                }
            }
            .padding(20)
        }
    }

    private func chooseRepositoryPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose the DockSheath git repository directory"
        if let existing = model.config.updateCheck.repositoryPath, !existing.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: existing)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.config.updateCheck.repositoryPath = url.path
    }
}
