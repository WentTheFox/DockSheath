// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DockSheath",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DockSheath", targets: ["DockSheath"]),
    ],
    targets: [
        .executableTarget(
            name: "DockSheath",
            dependencies: [
                "DockOverlayKit",
                "AXWindowKit",
                "JSON5Config",
                "TaskbarUI",
                "GlobalHotKey",
            ],
            path: "Sources/DockSheath",
            resources: [
                .copy("Resources/DefaultConfig.json5")
            ]
        ),
        .target(
            name: "DockOverlayKit",
            path: "Sources/DockOverlayKit"
        ),
        .target(
            name: "AXWindowKit",
            path: "Sources/AXWindowKit"
        ),
        .target(
            name: "JSON5Config",
            path: "Sources/JSON5Config"
        ),
        .target(
            name: "TaskbarUI",
            dependencies: [
                "AXWindowKit",
                "JSON5Config",
            ],
            path: "Sources/TaskbarUI"
        ),
        .target(
            name: "GlobalHotKey",
            dependencies: [
                "JSON5Config"
            ],
            path: "Sources/GlobalHotKey"
        ),
        .testTarget(
            name: "JSON5ConfigTests",
            dependencies: ["JSON5Config"],
            path: "Tests/JSON5ConfigTests"
        ),
        .testTarget(
            name: "AXWindowKitTests",
            dependencies: ["AXWindowKit"],
            path: "Tests/AXWindowKitTests"
        ),
    ]
)
