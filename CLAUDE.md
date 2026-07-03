# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

DockSheath is a free/open-source native macOS taskbar app (Swift, AppKit + some SwiftUI) — a FOSS alternative to uBar. It docks to whichever edge of the screen the real Dock is on, lists/manages running app windows, and adds a pinned quick-launch strip and a searchable app launcher. See `README.md` for the full feature/user-facing description.

## Build & test

This is a **pure Swift Package Manager project — there is no `.xcodeproj`**. That's deliberate (see Architecture below), not an oversight.

```sh
open Package.swift                             # opens directly in Xcode with full IDE support
swift build                                     # debug build
swift build -c release                          # release build
swift test                                      # run all tests (JSON5ConfigTests + AXWindowKitTests)
swift test --filter JSON5ConfigTests            # run one test target
swift test --filter JSON5ConfigTests.JSON5ParserTests/testHexNumbers   # run a single test method
Scripts/build_app.sh [debug|release] [out-dir]  # assemble a runnable DockSheath.app (defaults: release, build/)
```

There's no linter/formatter configured (no SwiftLint/swift-format config in the repo).

**This app can only be meaningfully exercised on a real Mac with Xcode/Swift 5.9+ installed.** If you're working from an environment without a macOS toolchain (this has happened before — an earlier session built the entire app from a Linux sandbox), you cannot compile or run tests locally. In that case, push to a branch and rely on the `build` GitHub Actions workflow (`.github/workflows/build.yml`) for real compiler feedback — do not claim something builds/works without verifying it either locally or via that CI run.

## Architecture

### The core trick: cover the Dock, don't replace it

DockSheath never hides, moves, or fights the real macOS Dock. Instead it draws a borderless overlay window on top of it. Because the real Dock is still present, macOS itself reserves that space in `NSScreen.visibleFrame` — so native double-click-to-maximize already respects the taskbar's footprint with zero private APIs. This spans three files that must be understood together:

- `Sources/DockOverlayKit/DockGeometry.swift` — computes the reserved rect by diffing `screen.frame` vs `screen.visibleFrame` on whichever edge (bottom/left/right) has a non-trivial inset. Also reads the Dock's `orientation`/`tilesize` preferences directly via `CFPreferencesCopyAppValue`, needed for the auto-hide case below.
- `Sources/DockOverlayKit/OverlayWindow.swift` — the actual overlay `NSWindow`. Its level is resolved at runtime via `CGWindowLevelForKey(.dockWindow) + 1` (never hardcoded — the raw level can shift across macOS versions).
- `Sources/DockOverlayKit/OverlayWindowController.swift` — owns the window's lifecycle, reacts to `NSApplication.didChangeScreenParametersNotification`, and reports edge changes (`onReservationChanged`) so `TaskbarUI` can flip between a horizontal layout (bottom) and vertical layout (left/right). It also re-checks geometry on a ~1s `Timer` (`geometryPollInterval`) as a deliberate belt-and-suspenders fallback — `refreshGeometry()` always reads the live `visibleFrame`, so this isn't caching/staleness insurance, it's just in case the notification doesn't fire promptly for every step of a live Dock icon-size drag in System Settings.

**Auto-hide is a separate code path, not an edge case of the above.** When the Dock is set to auto-hide, macOS reserves *no* space at all (the hover-reveal is a temporary overlay, not a layout change), so `visibleFrame` gives no signal. `OverlayWindowController` detects this (`DockHealthCheck.isAutoHideEnabled()`) and switches to mirroring mode: the taskbar stays hidden, and a global+local `NSEvent` mouse-moved monitor watches for the cursor approaching the Dock's configured edge (read from the `orientation` preference, since geometry can't help here), revealing/concealing the taskbar to mirror the real Dock's own behavior.

### Module dependency graph

Defined in `Package.swift`. Bottom-up:
- `DockOverlayKit`, `AXWindowKit`, `JSON5Config` — foundational, no internal dependencies on each other.
- `TaskbarUI` depends on all three of the above (needs `AXWindowKit` for window control, `JSON5Config` for `PinnedAppEntry`, `DockOverlayKit` for `DockEdge` to lay itself out correctly).
- `GlobalHotKey` depends on `JSON5Config` (for the `HotKeyBinding` type).
- `DockSheath` (the executable target, app bootstrap/onboarding/status item) depends on everything.

### Window enumeration (`AXWindowKit`)

Deliberately uses `NSWorkspace.runningApplications` + `AXUIElement` (`kAXWindowsAttribute`, `kAXTitleAttribute`, etc.) as the source of truth for window existence, minimized state, *and* titles — not `CGWindowListCopyWindowInfo`. Reading a window's AX title does not require Screen Recording permission (only Accessibility does), unlike `CGWindowListCopyWindowInfo`'s window name. Actions (activate/minimize/close) go through `AXUIElementPerformAction`/attribute writes in `AccessibilityWindowController.swift`.

The app is **intentionally non-sandboxed** (no `com.apple.security.app-sandbox` key in `Sources/DockSheath/App/DockSheath.entitlements`) — sandboxed apps can't control other processes' windows via the Accessibility API. This rules out Mac App Store distribution; DockSheath ships via GitHub Releases only.

### Config pipeline (`JSON5Config`)

`Sources/JSON5Config/JSON5Parser.swift` is a hand-written recursive-descent parser for the **full** JSON5 spec (not a restricted subset — an earlier version was, then got upgraded). It parses into a `JSON5Value` tree, which `.toFoundation()` converts to plain Foundation types; those get re-serialized via `JSONSerialization` and handed to `JSONDecoder` so `Codable`/`TaskbarConfig` decoding is reused unchanged.

**Gotcha that has already caused a real bug**: Swift's synthesized `Decodable` does *not* apply a type's memberwise-initializer defaults to missing JSON keys — it just requires every key present for non-Optional properties. `TaskbarConfig`, `BehaviorConfig`, and `AppearanceConfig` in `ConfigSchema.swift` all have hand-written `init(from:)` implementations specifically to work around this (using `decodeIfPresent(...) ?? default`). If you add a new non-Optional field to any config struct, you must add it to that struct's custom decoder too, or a config file missing that key will fail to parse instead of falling back to the default.

Config lives at `~/.config/docksheath/config.json5` and is live-reloaded via `ConfigFileWatcher.swift` (`DispatchSource` on the file, debounced ~300ms, reopens the fd by path on every event since editors often save via delete+recreate).

### CI/CD (`.github/workflows/`)

Three workflows, all runners pinned to specific action commit SHAs (kept current by `.github/dependabot.yml`):
- `build.yml` — runs on push/PR to `main`: `swift build`, `swift test`, then an `xcodebuild -scheme DockSheath` sanity build.
- `dev-release.yml` — runs on push to `main` (repo is public, so macOS Actions runners are free): auto-tags `v0.0.1-dev<unix-timestamp>` and publishes a pre-release DMG.
- `release.yml` — manual: triggered by pushing a real `vX.Y.Z` tag, publishes a pre-release DMG. Its tag pattern explicitly excludes `v*-dev*` so it never double-fires on `dev-release.yml`'s auto-generated tags.

Releases are **ad-hoc code-signed** (`codesign --force --deep --sign -`, no paid Apple Developer ID) and published via the `gh` CLI directly (`gh release create ...` in a plain `run:` step) rather than a third-party GitHub Action, specifically to avoid needing to pin/verify another action's SHA.
