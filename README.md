# DockSheath

[![Build](https://github.com/WentTheFox/MacOSTaskbar/actions/workflows/build.yml/badge.svg)](https://github.com/WentTheFox/MacOSTaskbar/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

A free, open-source, native Windows-style taskbar for macOS — a FOSS alternative to uBar and similar Dock replacements. DockSheath docks at the bottom of the screen, lists and manages running app windows, and adds a pinned quick-launch strip and a start-menu-style app launcher.

The project name is inspired by the concept of hiding the dock when not needed (like sheathing a sword), while also being a reflecton of my personal opinion of MacOS when read aloud quickly. To some, it may also be their opinion of a purely vibe-coded project, which this very much is.

## How it works

Unlike apps that try to hide or replace the real macOS Dock, **DockSheath leaves the Dock running** and simply draws its own taskbar on top of it, covering it visually. Because the real Dock is still present on whichever edge of the screen it occupies, macOS itself reserves that space in `NSScreen.visibleFrame` — so double-clicking a window's title bar to maximize just works, with no windows getting cut off behind the taskbar, and no private APIs involved.

DockSheath follows the Dock to wherever it is — bottom, left, or right — laying itself out horizontally at the bottom or vertically on the side to match. If the Dock is set to **auto-hide**, there's no reserved space to cover (macOS treats an auto-hidden Dock's hover-reveal as a temporary overlay, not a layout change), so DockSheath mirrors it instead: hidden until the mouse reaches that edge, hidden again shortly after it moves away. If DockSheath can't find the Dock reserving space or auto-hidden on any edge at all, it warns you from its menu bar item.

Need the real Dock for something DockSheath doesn't replicate (Trash, Launchpad, right-click Dock menus)? Hide the DockSheath taskbar instantly from the menu bar item or a configurable global hotkey (default `⌘⌥D`) to reveal it underneath.

## Features

- Taskbar docked to whichever screen edge the Dock is on (bottom, left, or right) with genuine screen-space reservation
- Running windows grouped by app by default — click to activate/minimize, right-click to close, with each button's label showing that window's title (or "AppName (N)" plus a tooltip listing every title when an app has several windows); set `behavior.groupWindowsByApp` to `false` in config for one button per window instead
- Pinned "quick launch" apps strip, separate from running windows
- Start-menu-style searchable app launcher
- Hand-editable JSON5 configuration (comments + trailing commas supported), live-reloaded on save
- Taskbar and button colors follow the system light/dark appearance by default, with per-element background/border/text overrides available in config
- Toggle the taskbar via menu bar item or global hotkey to reveal the real Dock underneath

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (or the Swift 5.9+ command-line toolchain) to build — DockSheath isn't distributed as a pre-built binary, see [Installation](#installation)
- **Accessibility** permission (required — lets DockSheath list, activate, minimize, and close other apps' windows)
- The system Dock enabled on some edge of the screen — visible or auto-hidden, DockSheath follows either

## Installation

DockSheath doesn't ship pre-built binaries — build and run it from source:

```sh
git clone https://github.com/WentTheFox/MacOSTaskbar.git
cd MacOSTaskbar
swift build -c release
Scripts/build_app.sh release build   # assembles build/DockSheath.app
open build/DockSheath.app
```

Or `open Package.swift` to build and run directly from Xcode instead. Move `build/DockSheath.app` to `/Applications` if you want it to stick around.

To pull the latest changes and rebuild an existing install in one step, run `Scripts/update.sh` (defaults to `/Applications`, or pass a different install directory). It quits the running app if needed, replaces the installed `.app`, and clears the quarantine attribute (`xattr -cr`) on the newly built binary so Gatekeeper doesn't block it — every rebuild gets a fresh ad-hoc signature, so you'll need to re-grant Accessibility access after each update.

## Permissions

On first launch, DockSheath walks you through granting **Accessibility** access (System Settings → Privacy & Security → Accessibility). This is required for the taskbar to see and control other apps' windows. If you grant access after DockSheath is already running, you may need to quit and relaunch it for the grant to take effect — this is a general macOS quirk, not specific to DockSheath.

## Configuration

DockSheath stores its config at:

```
~/.config/docksheath/config.json5
```

A commented default is generated on first run. It supports the full [JSON5 spec](https://spec.json5.org) — comments, trailing commas, unquoted keys, single-quoted strings, and more. Edits are picked up automatically while DockSheath is running — no restart needed.

Note: pinning/unpinning an app from the taskbar UI rewrites the file as plain JSON and will remove any comments you've added — hand-edit comments back in afterward if you'd like to keep them.

## Contributing

The codebase is split into focused Swift Package targets under `Sources/`:

- `DockSheath` — app bootstrap, menu bar item, onboarding
- `DockOverlayKit` — the Dock-covering overlay window and screen-space-reservation geometry
- `AXWindowKit` — window enumeration/control via the Accessibility API
- `JSON5Config` — the JSON5 parser and config store
- `TaskbarUI` — taskbar chrome, pinned apps, and the quick-launch panel
- `GlobalHotKey` — the systemwide show/hide shortcut

Run `swift test` to run the `JSON5Config`/`AXWindowKit` test suites.

Pull requests welcome. Since DockSheath needs Accessibility access to do anything useful, and ad-hoc code signatures change on every local rebuild, macOS's permission system (TCC) may re-prompt you repeatedly while iterating — using a stable local self-signed code-signing certificate for development builds avoids this (see Apple's documentation on creating a certificate in Keychain Access and set it as your local `codesign` identity instead of `-`).

## Known limitations

- Single-display only for now — the taskbar appears on the main screen (multi-monitor support is planned)
- Not distributed on the Mac App Store (DockSheath runs unsandboxed by necessity, since sandboxed apps can't control other apps' windows via the Accessibility API)
- Window content thumbnails/previews are not implemented yet
- The real Dock's own hover tooltips can still appear while it's covered by the taskbar. DockSheath's overlay window does correctly intercept mouse events for its own buttons (it isn't click-through), so this points to the Dock using its own cursor-position tracking that isn't gated by window occlusion — there's no public API to suppress another app's UI, so this isn't something DockSheath can fix

## License

[MIT](LICENSE)
