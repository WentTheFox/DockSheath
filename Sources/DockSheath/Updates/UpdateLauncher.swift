import AppKit

/// Launches `Scripts/update.sh` in the user's default terminal app and
/// reopens DockSheath once it finishes successfully.
///
/// `update.sh` is unavoidably interactive (a blocking keypress prompt for
/// the code-signing trust check, plus possible git-credential/keychain
/// prompts), so it can never be run headlessly from inside this process —
/// it needs a real TTY the user can type into. Driving it as a plain
/// in-process `Process` (as `DockHealthCheck.run` does for quick
/// non-interactive commands) is unsuitable here for the same reason.
enum UpdateLauncher {
    enum LaunchError: Error, CustomStringConvertible {
        case noRepositoryPath
        case repositoryNotFound(String)
        case updateScriptMissing(String)

        var description: String {
            switch self {
            case .noRepositoryPath:
                return "No repository path is configured — set one in Settings > General > Updates."
            case .repositoryNotFound(let path):
                return "Repository path doesn't exist: \(path)"
            case .updateScriptMissing(let path):
                return "Scripts/update.sh wasn't found in \(path)"
            }
        }
    }

    /// Writes a `.command` wrapper script to a temp file and opens it via
    /// `NSWorkspace`, which hands it to whatever app is registered as the
    /// user's default handler for shell scripts (Terminal.app unless
    /// they've set something else, e.g. iTerm2) — this is what lets the
    /// script run in "the default terminal app" rather than a hardcoded
    /// one, unlike driving Terminal.app directly via AppleScript.
    ///
    /// The wrapper `git pull`s the repository itself *before* invoking
    /// `update.sh`, rather than relying on `update.sh`'s own internal `git
    /// pull` (its first line): if update.sh had already been read into
    /// bash's interpreter before that internal pull ran, a change to
    /// update.sh itself as part of the same update could be silently
    /// missed. Pulling first here guarantees the copy of update.sh that
    /// actually executes is current.
    ///
    /// Must be called from the main thread (`NSWorkspace`). Once
    /// `NSWorkspace.shared.open` returns, the launched terminal session is
    /// fully independent of this app's process — update.sh killing the
    /// running DockSheath process partway through (its own "quit the
    /// running app before replacing it" step) does not interrupt the
    /// wrapper script, since it was never DockSheath's child process.
    static func launchUpdateAndRestart(repositoryPath: String?) throws {
        guard let repositoryPath, !repositoryPath.isEmpty else {
            throw LaunchError.noRepositoryPath
        }
        guard FileManager.default.fileExists(atPath: repositoryPath) else {
            throw LaunchError.repositoryNotFound(repositoryPath)
        }
        let updateScriptPath = (repositoryPath as NSString).appendingPathComponent("Scripts/update.sh")
        guard FileManager.default.fileExists(atPath: updateScriptPath) else {
            throw LaunchError.updateScriptMissing(repositoryPath)
        }

        let appBundlePath = Bundle.main.bundleURL.path
        let installDir = Bundle.main.bundleURL.deletingLastPathComponent().path

        let script = """
        #!/bin/bash
        set -e
        cd \(shellQuoted(repositoryPath))
        echo "==> Pulling latest changes (so update.sh itself is current)"
        git pull
        \(shellQuoted(updateScriptPath)) \(shellQuoted(installDir))
        echo "==> Relaunching DockSheath"
        open \(shellQuoted(appBundlePath))
        rm -- "$0"
        """

        let wrapperURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("docksheath-update-\(UUID().uuidString).command")
        try script.write(to: wrapperURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperURL.path)

        NSWorkspace.shared.open(wrapperURL)
    }

    private static func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
