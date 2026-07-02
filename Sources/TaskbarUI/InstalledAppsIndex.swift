import AppKit

public struct InstalledApp: Identifiable, Hashable {
    public var id: String { bundlePath }
    public let name: String
    public let bundlePath: String
    public let bundleIdentifier: String?

    public init(name: String, bundlePath: String, bundleIdentifier: String?) {
        self.name = name
        self.bundlePath = bundlePath
        self.bundleIdentifier = bundleIdentifier
    }

    public var icon: NSImage {
        NSWorkspace.shared.icon(forFile: bundlePath)
    }
}

/// Discovers installed applications by walking well-known Applications
/// directories directly via `FileManager`, rather than relying on Spotlight
/// (`NSMetadataQuery`) as the sole mechanism — some users disable Spotlight
/// indexing entirely, which would silently return zero results for them.
public enum InstalledAppsIndex {
    private static let searchDirectories: [String] = [
        "/Applications",
        "/System/Applications",
        NSHomeDirectory() + "/Applications",
    ]

    /// Scans the standard Applications directories (and one level of
    /// subfolders, e.g. `/System/Applications/Utilities`) for `.app` bundles.
    public static func scan() -> [InstalledApp] {
        var results: [InstalledApp] = []
        var seenPaths: Set<String> = []

        for directory in searchDirectories {
            for path in appBundlePaths(in: directory, recurseOneLevel: true) {
                guard !seenPaths.contains(path) else { continue }
                seenPaths.insert(path)
                if let app = makeInstalledApp(bundlePath: path) {
                    results.append(app)
                }
            }
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func appBundlePaths(in directory: String, recurseOneLevel: Bool) -> [String] {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return []
        }

        var paths: [String] = []
        for entry in entries {
            let fullPath = (directory as NSString).appendingPathComponent(entry)
            if entry.hasSuffix(".app") {
                paths.append(fullPath)
            } else if recurseOneLevel {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory), isDirectory.boolValue {
                    paths.append(contentsOf: appBundlePaths(in: fullPath, recurseOneLevel: false))
                }
            }
        }
        return paths
    }

    private static func makeInstalledApp(bundlePath: String) -> InstalledApp? {
        let bundle = Bundle(path: bundlePath)
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? (bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        return InstalledApp(name: name, bundlePath: bundlePath, bundleIdentifier: bundle?.bundleIdentifier)
    }
}
