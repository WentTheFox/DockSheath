import SwiftUI

/// Every field in `secondaryDisplay.taskbar`/`secondaryDisplay.appearance`
/// reduces to the same shape: `nil` means "inherit the main config's value",
/// anything else replaces it (see `AppearanceConfig.applying(_:)`/
/// `TaskbarAppearanceConfig.applying(_:)`). This renders that as a checkbox
/// that materializes `makeDefault()` when turned on and clears back to `nil`
/// when turned off, with `content` only shown while overridden.
struct OverrideRow<Value, Content: View>: View {
    let title: String
    @Binding var value: Value?
    let makeDefault: () -> Value
    @ViewBuilder var content: (Binding<Value>) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: isOverriddenBinding) {
                Text(title)
            }
            .toggleStyle(.checkbox)

            if value != nil {
                content(nonNilBinding)
                    .padding(.leading, 20)
            }
        }
    }

    private var isOverriddenBinding: Binding<Bool> {
        Binding(
            get: { value != nil },
            set: { isOn in value = isOn ? makeDefault() : nil }
        )
    }

    private var nonNilBinding: Binding<Value> {
        Binding(
            get: { value ?? makeDefault() },
            set: { value = $0 }
        )
    }
}
