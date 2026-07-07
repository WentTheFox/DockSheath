import AppKit
import SwiftUI
import JSON5Config
import TaskbarUI

/// A labeled family-name field + size slider bound to a `FontConfig`, with a
/// live preview rendered in the actual resolved font — including a hint when
/// a typed family name doesn't match any installed font, since `resolvedFont`
/// silently falls back to the system font in that case rather than erroring.
struct FontConfigRow: View {
    let label: String
    @Binding var font: FontConfig
    var weight: NSFont.Weight = .regular

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("System Default", text: familyBinding)
                Text("Size")
                Slider(value: $font.size, in: 8...24, step: 1)
                Text("\(Int(font.size)) pt")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
            HStack(spacing: 6) {
                Text("\(label) preview")
                    .font(Font(TaskbarTheme.resolvedFont(family: font.family, size: font.size, weight: weight)))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !familyIsKnown {
                    Text("Font not found — using system default")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var familyBinding: Binding<String> {
        Binding(
            get: { font.family ?? "" },
            set: { font.family = $0.isEmpty ? nil : $0 }
        )
    }

    private var familyIsKnown: Bool {
        guard let family = font.family, !family.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        return NSFontManager.shared.availableFontFamilies.contains { $0.caseInsensitiveCompare(family) == .orderedSame }
    }
}
