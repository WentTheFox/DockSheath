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
                            detectedRepositoryPath ?? "Not set",
                            text: Binding(
                                get: { model.config.updateCheck.repositoryPath ?? "" },
                                set: { model.config.updateCheck.repositoryPath = $0.isEmpty ? nil : $0 }
                            )
                        )
                        Button("Choose…") { chooseRepositoryPath() }
                    }

                    if model.config.updateCheck.repositoryPath == nil {
                        Text(
                            detectedRepositoryPath.map { "Defaulting to \($0), detected from where DockSheath is running." }
                                ?? "Couldn't detect a repository automatically — set one to enable update checks."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Button("Check for Updates Now") {
                        model.onCheckForUpdatesNow?()
                    }
                    .disabled(effectiveRepositoryPath == nil)
                }
            }
            .padding(20)
        }
    }

    /// Best-effort default shown/used when the user hasn't set
    /// `repositoryPath` explicitly — see `UpdateChecker.detectRepositoryPath()`.
    private var detectedRepositoryPath: String? {
        UpdateChecker.detectRepositoryPath()
    }

    private var effectiveRepositoryPath: String? {
        model.config.updateCheck.repositoryPath ?? detectedRepositoryPath
    }

    private func chooseRepositoryPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose the DockSheath git repository directory"
        if let existing = effectiveRepositoryPath {
            panel.directoryURL = URL(fileURLWithPath: existing)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.config.updateCheck.repositoryPath = url.path
    }
}
