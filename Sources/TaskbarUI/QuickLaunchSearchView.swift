import SwiftUI

public struct QuickLaunchSearchView: View {
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool
    private let allApps: [InstalledApp]
    private let onLaunch: (InstalledApp) -> Void
    private let onPin: ((InstalledApp) -> Void)?

    public init(allApps: [InstalledApp], onLaunch: @escaping (InstalledApp) -> Void, onPin: ((InstalledApp) -> Void)? = nil) {
        self.allApps = allApps
        self.onLaunch = onLaunch
        self.onPin = onPin
    }

    private var filteredApps: [InstalledApp] {
        FuzzySearch.filterAndSort(allApps, query: query, text: \.name)
    }

    public var body: some View {
        VStack(spacing: 0) {
            TextField("Search apps…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .padding(10)
                .focused($isSearchFocused)
                .onChange(of: query) { _ in selectedIndex = 0 }
                .onSubmit(launchSelected)
                .onAppear { isSearchFocused = true }

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredApps.enumerated()), id: \.element.id) { index, app in
                        QuickLaunchRow(app: app, isSelected: index == selectedIndex)
                            .contentShape(Rectangle())
                            .onTapGesture { onLaunch(app) }
                            .contextMenu {
                                if let onPin {
                                    Button("Pin to Taskbar") { onPin(app) }
                                }
                            }
                    }
                }
            }
            .frame(maxHeight: 360)
        }
        .frame(width: 420)
        .background(.regularMaterial)
    }

    private func launchSelected() {
        guard filteredApps.indices.contains(selectedIndex) else { return }
        onLaunch(filteredApps[selectedIndex])
    }
}

private struct QuickLaunchRow: View {
    let app: InstalledApp
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 28, height: 28)
            Text(app.name)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }
}
