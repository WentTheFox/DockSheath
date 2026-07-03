import AppKit
import SwiftUI
import TaskbarUI

/// A labeled color row bound to an optional hex string, matching
/// `TaskbarColorOverrides`/`ButtonColorOverrides`'s null-means-"follow the
/// system appearance" convention: unchecked leaves `hex` `nil`, checked
/// materializes `fallback` (converted to hex) and shows a `ColorPicker`.
struct OptionalColorRow: View {
    let title: String
    @Binding var hex: String?
    var fallback: Color = .gray

    var body: some View {
        HStack {
            Toggle(isOn: isCustomBinding) {
                Text(title)
            }
            .toggleStyle(.checkbox)

            if hex != nil {
                ColorPicker("", selection: colorBinding, supportsOpacity: true)
                    .labelsHidden()
            }

            Spacer()
        }
    }

    private var isCustomBinding: Binding<Bool> {
        Binding(
            get: { hex != nil },
            set: { isOn in hex = isOn ? NSColor(fallback).hexString : nil }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { hex.flatMap { NSColor(hexString: $0) }.map { Color($0) } ?? fallback },
            set: { hex = NSColor($0).hexString }
        )
    }
}
