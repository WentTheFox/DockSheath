import SwiftUI
import AXWindowKit

final class PermissionsStatus: ObservableObject {
    @Published var isAccessibilityTrusted: Bool = PermissionChecks.isAccessibilityTrusted
    @Published var isScreenRecordingGranted: Bool = PermissionChecks.isScreenRecordingGranted

    private var timer: Timer?

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        isAccessibilityTrusted = PermissionChecks.isAccessibilityTrusted
        isScreenRecordingGranted = PermissionChecks.isScreenRecordingGranted
    }
}

struct PermissionsOnboardingView: View {
    @ObservedObject var status: PermissionsStatus
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to DockSheath")
                .font(.title2)
                .bold()

            Text("DockSheath needs Accessibility access to list and control other apps' windows. " +
                 "It draws its taskbar over the real Dock rather than replacing it, so keep the Dock " +
                 "visible and positioned at the bottom of the screen.")
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            permissionRow(
                title: "Accessibility",
                detail: "Required — lets DockSheath list, activate, minimize, and close windows.",
                granted: status.isAccessibilityTrusted,
                action: { PermissionChecks.requestAccessibilityAccess() }
            )

            permissionRow(
                title: "Screen Recording",
                detail: "Optional — not required for DockSheath's core features today.",
                granted: status.isScreenRecordingGranted,
                action: { PermissionChecks.requestScreenRecordingAccess() }
            )

            if status.isAccessibilityTrusted {
                Text("You may need to relaunch DockSheath after granting a permission for it to take effect.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Continue") { onContinue() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!status.isAccessibilityTrusted)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear { status.startPolling() }
        .onDisappear { status.stopPolling() }
    }

    private func permissionRow(title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(granted ? .green : .orange)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).bold()
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }

            Spacer()

            if !granted {
                Button("Grant…", action: action)
            }
        }
    }
}
