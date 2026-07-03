import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }

            AppearanceSettingsView(model: model)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            SecondaryDisplaySettingsView(model: model)
                .tabItem { Label("Secondary Display", systemImage: "rectangle.on.rectangle") }

            HotkeySettingsView(model: model)
                .tabItem { Label("Hotkey", systemImage: "keyboard") }

            PinnedAppsSettingsView(model: model)
                .tabItem { Label("Pinned Apps", systemImage: "pin") }
        }
        .frame(width: 520, height: 480)
    }
}
