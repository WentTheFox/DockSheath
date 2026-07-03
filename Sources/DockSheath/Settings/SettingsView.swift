import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            AppearanceSettingsView(model: model)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
                .tag(SettingsTab.appearance)

            SecondaryDisplaySettingsView(model: model)
                .tabItem { Label("Secondary Display", systemImage: "rectangle.on.rectangle") }
                .tag(SettingsTab.secondaryDisplay)

            HotkeySettingsView(model: model)
                .tabItem { Label("Hotkey", systemImage: "keyboard") }
                .tag(SettingsTab.hotkey)

            PinnedAppsSettingsView(model: model)
                .tabItem { Label("Pinned Apps", systemImage: "pin") }
                .tag(SettingsTab.pinnedApps)
        }
        .frame(width: 520, height: 480)
    }
}
