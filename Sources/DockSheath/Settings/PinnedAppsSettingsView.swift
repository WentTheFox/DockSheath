import AppKit
import SwiftUI
import JSON5Config
import TaskbarUI

struct PinnedAppsSettingsView: View {
    @ObservedObject var model: SettingsModel
    @State private var query = ""
    @State private var allApps: [InstalledApp] = []

    private var pinnedPaths: Set<String> {
        Set(model.config.pinnedApps.map(\.bundlePath))
    }

    private var searchResults: [InstalledApp] {
        guard !query.isEmpty else { return [] }
        return FuzzySearch.filterAndSort(allApps, query: query, text: \.name)
            .filter { !pinnedPaths.contains($0.bundlePath) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pinned Apps")
                .font(.headline)

            List {
                ForEach(model.config.pinnedApps) { entry in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: entry.bundlePath))
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text((entry.bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: ""))
                        Spacer()
                        Button("Remove") {
                            model.config.pinnedApps.removeAll { $0.id == entry.id }
                        }
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
                        Button("Pin") {
                            model.config.pinnedApps.append(
                                PinnedAppEntry(bundlePath: app.bundlePath, bundleIdentifier: app.bundleIdentifier)
                            )
                            query = ""
                        }
                    }
                }
                .frame(minHeight: 120)
            }
        }
        .padding(20)
    }
}
