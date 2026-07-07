import Foundation

/// Compares DockSheath's git clone (`repositoryPath`, a user-configured
/// setting — the installed .app has no way to know where its own source
/// lives) against its remote-tracking branch, to power the "Update
/// Available" affordance in the Quick Launch and status bar menus.
///
/// Every check runs on a background queue (`git fetch` is a network call)
/// and reports back on the main thread via `onStatusChanged`. Failures are
/// deliberately terse and never surfaced as an alert here — that's left to
/// callers driving an explicit "Check for Updates Now" action, since a
/// silent background check shouldn't interrupt the user with error dialogs.
final class UpdateChecker {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(commitsBehind: Int)
        case error(String)
    }

    private(set) var status: Status = .idle {
        didSet { onStatusChanged?(status) }
    }
    /// Always called on the main thread.
    var onStatusChanged: ((Status) -> Void)?

    private let queue = DispatchQueue(label: "tf.went.docksheath.update-check", qos: .utility)

    /// No-ops (reporting `.error`) if `repositoryPath` is empty — callers
    /// don't need to pre-validate it themselves.
    func checkNow(repositoryPath: String?) {
        guard let repositoryPath, !repositoryPath.isEmpty else {
            status = .error("No repository path configured")
            return
        }

        status = .checking
        queue.async { [weak self] in
            let result = Self.performCheck(repositoryPath: repositoryPath)
            DispatchQueue.main.async {
                self?.status = result
            }
        }
    }

    /// Runs entirely off the main thread — see `checkNow(repositoryPath:)`.
    private static func performCheck(repositoryPath: String) -> Status {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: repositoryPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .error("Repository path doesn't exist")
        }
        guard FileManager.default.fileExists(atPath: (repositoryPath as NSString).appendingPathComponent(".git")) else {
            return .error("Not a git repository")
        }

        // Fetch first so the upstream comparison below reflects the
        // remote's actual current state, not a stale local cache.
        // GIT_TERMINAL_PROMPT=0 makes a credential prompt fail fast instead
        // of hanging the background queue indefinitely.
        guard let fetchResult = run(["fetch", "--quiet"], in: repositoryPath), fetchResult.exitCode == 0 else {
            return .error("Couldn't reach the remote (network or authentication issue)")
        }

        guard let upstreamResult = run(
            ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            in: repositoryPath
        ), upstreamResult.exitCode == 0 else {
            return .error("No upstream branch configured")
        }

        guard let countResult = run(["rev-list", "--count", "HEAD..@{upstream}"], in: repositoryPath),
              countResult.exitCode == 0,
              let count = Int(countResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return .error("Couldn't compare local and remote commits")
        }

        return count > 0 ? .updateAvailable(commitsBehind: count) : .upToDate
    }

    private struct GitResult {
        let exitCode: Int32
        let stdout: String
    }

    private static func run(_ arguments: [String], in directory: String, timeout: TimeInterval = 15) -> GitResult? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        process.environment = (ProcessInfo.processInfo.environment).merging(
            ["GIT_TERMINAL_PROMPT": "0"], uniquingKeysWith: { _, new in new }
        )

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        // A hard timeout so a wedged `fetch` (bad network, waiting on a
        // credential helper despite GIT_TERMINAL_PROMPT=0) can't hang this
        // background queue forever.
        let timeoutWorkItem = DispatchWorkItem { [process] in
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)

        // Read before waiting on exit — draining the pipe only after
        // `waitUntilExit()` can deadlock if the child fills the pipe buffer
        // and blocks on a write nobody's reading yet.
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeoutWorkItem.cancel()

        return GitResult(exitCode: process.terminationStatus, stdout: String(data: data, encoding: .utf8) ?? "")
    }
}

extension UpdateChecker.Status {
    /// Short, user-facing summary for a manual "Check for Updates Now"
    /// result alert. Not used for the silent automatic check.
    var userFacingMessage: String {
        switch self {
        case .idle, .checking:
            return "Checking for updates…"
        case .upToDate:
            return "You're up to date."
        case .updateAvailable(let commitsBehind):
            return commitsBehind == 1
                ? "1 update is available."
                : "\(commitsBehind) updates are available."
        case .error(let reason):
            return "Couldn't check for updates: \(reason)"
        }
    }
}
