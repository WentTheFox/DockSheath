import AppKit
import SwiftUI
import JSON5Config
import TaskbarUI

struct PinnedAppsSettingsView: View {
    @ObservedObject var model: SettingsModel
    @State private var query = ""
    @State private var allApps: [InstalledApp] = []

    private var taskbarPaths: Set<String> {
        Set(model.config.pinnedApps.map(\.bundlePath))
    }

    private var quickLaunchPaths: Set<String> {
        Set(model.config.quickLaunchFavorites.map(\.bundlePath))
    }

    /// Every app pinned to either list, deduplicated by `bundlePath` —
    /// `pinnedApps`' own order first, then any quick-launch-only extras.
    private var pinnedSomewhere: [PinnedAppEntry] {
        var seen = Set<String>()
        var result: [PinnedAppEntry] = []
        for entry in model.config.pinnedApps + model.config.quickLaunchFavorites {
            guard !seen.contains(entry.bundlePath) else { continue }
            seen.insert(entry.bundlePath)
            result.append(entry)
        }
        return result
    }

    private var searchResults: [InstalledApp] {
        guard !query.isEmpty else { return [] }
        return FuzzySearch.filterAndSort(allApps, query: query, text: \.name)
            .filter { !(taskbarPaths.contains($0.bundlePath) && quickLaunchPaths.contains($0.bundlePath)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pinned Apps")
                    .font(.headline)

                List {
                    ForEach(pinnedSomewhere) { entry in
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: entry.bundlePath))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text((entry.bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: ""))
                            Spacer()
                            Toggle("Taskbar", isOn: taskbarBinding(bundlePath: entry.bundlePath, bundleIdentifier: entry.bundleIdentifier))
                            Toggle("Quick Launch", isOn: quickLaunchBinding(bundlePath: entry.bundlePath, bundleIdentifier: entry.bundleIdentifier))
                        }
                    }
                }
                .frame(minHeight: 120)

                Divider()

                Text("Add an app")
                    .font(.subheadline)
                TextField("Search installed apps…", text: $query)
                    .onAppear { if allApps.isEmpty { allApps = InstalledAppsIndex.scan() } }

                if !searchResults.isEmpty {
                    List(searchResults.prefix(8)) { app in
                        HStack {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(app.name)
                            Spacer()
                            Toggle("Taskbar", isOn: taskbarBinding(bundlePath: app.bundlePath, bundleIdentifier: app.bundleIdentifier))
                            Toggle("Quick Launch", isOn: quickLaunchBinding(bundlePath: app.bundlePath, bundleIdentifier: app.bundleIdentifier))
                        }
                    }
                    .frame(minHeight: 120)
                }
            }
            .padding(20)
        }
    }

    private func taskbarBinding(bundlePath: String, bundleIdentifier: String?) -> Binding<Bool> {
        Binding(
            get: { model.config.pinnedApps.contains { $0.bundlePath == bundlePath } },
            set: { isOn in
                if isOn {
                    guard !model.config.pinnedApps.contains(where: { $0.bundlePath == bundlePath }) else { return }
                    model.config.pinnedApps.append(PinnedAppEntry(bundlePath: bundlePath, bundleIdentifier: bundleIdentifier))
                } else {
                    model.config.pinnedApps.removeAll { $0.bundlePath == bundlePath }
                }
            }
        )
    }

    private func quickLaunchBinding(bundlePath: String, bundleIdentifier: String?) -> Binding<Bool> {
        Binding(
            get: { model.config.quickLaunchFavorites.contains { $0.bundlePath == bundlePath } },
            set: { isOn in
                if isOn {
                    guard !model.config.quickLaunchFavorites.contains(where: { $0.bundlePath == bundlePath }) else { return }
                    model.config.quickLaunchFavorites.append(PinnedAppEntry(bundlePath: bundlePath, bundleIdentifier: bundleIdentifier))
                } else {
                    model.config.quickLaunchFavorites.removeAll { $0.bundlePath == bundlePath }
                }
            }
        )
    }
}
