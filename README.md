# DockSheath

[![Build](https://github.com/WentTheFox/MacOSTaskbar/actions/workflows/build.yml/badge.svg)](https://github.com/WentTheFox/MacOSTaskbar/actions/workflows/build.yml)
[![Release](https://github.com/WentTheFox/MacOSTaskbar/actions/workflows/release.yml/badge.svg)](https://github.com/WentTheFox/MacOSTaskbar/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

A free, open-source, native Windows-style taskbar for macOS — a FOSS alternative to uBar and similar Dock replacements. DockSheath docks at the bottom of the screen, lists and manages running app windows, and adds a pinned quick-launch strip and a start-menu-style app launcher.

The project name is inspired by the concept of hiding the dock when not needed (like sheathing a sword), while also being a reflecton of my personal opinion of MacOS when read aloud quickly. To some, it may also be there their opinion of a purely vibe-coded project, which this very much is.

## How it works

Unlike apps that try to hide or replace the real macOS Dock, **DockSheath leaves the Dock running** and simply draws its own taskbar on top of it, covering it visually. Because the real Dock is still present at the bottom of the screen, macOS itself reserves that space in `NSScreen.visibleFrame` — so double-clicking a window's title bar to maximize just works, with no windows getting cut off behind the taskbar, and no private APIs involved.

This means DockSheath requires the system Dock to stay **visible and positioned at the bottom of the screen** (not auto-hidden, not on the left/right). DockSheath detects and warns you if this isn't the case, with a one-click fix available from its menu bar item.

Need the real Dock for something DockSheath doesn't replicate (Trash, Launchpad, right-click Dock menus)? Hide the DockSheath taskbar instantly from the menu bar item or a configurable global hotkey (default `⌘⌥D`) to reveal it underneath.

## Features

- Taskbar docked at the bottom of the screen with genuine screen-space reservation
- Running windows grouped by app — click to activate/minimize, right-click to close
- Pinned "quick launch" apps strip, separate from running windows
- Start-menu-style searchable app launcher
- Hand-editable JSON5 configuration (comments + trailing commas supported), live-reloaded on save
- Toggle the taskbar via menu bar item or global hotkey to reveal the real Dock underneath

## Requirements

- macOS 13 Ventura or later
- **Accessibility** permission (required — lets DockSheath list, activate, minimize, and close other apps' windows)
- The system Dock set to **visible** (not auto-hidden) and positioned at the **bottom** of the screen

## Installation

1. Download the latest `.dmg` from [Releases](https://github.com/WentTheFox/MacOSTaskbar/releases)
2. Open the DMG and drag `DockSheath.app` to `/Applications`
3. See [Gatekeeper bypass](#gatekeeper-bypass) below before first launch

### Gatekeeper bypass

DockSheath is not signed with a paid Apple Developer ID (this is a free, community-run project), so macOS Gatekeeper will block the first launch. To open it:

- **Right-click (or Control-click) `DockSheath.app` → Open**, then confirm in the dialog that appears, **or**
- Run this in Terminal after moving it to `/Applications`:
  ```sh
  xattr -cr /Applications/DockSheath.app
  ```

You only need to do this once.

## Permissions

On first launch, DockSheath walks you through granting **Accessibility** access (System Settings → Privacy & Security → Accessibility). This is required for the taskbar to see and control other apps' windows. If you grant access after DockSheath is already running, you may need to quit and relaunch it for the grant to take effect — this is a general macOS quirk, not specific to DockSheath.

## Configuration

DockSheath stores its config at:

```
~/.config/docksheath/config.json5
```

A commented default is generated on first run. It supports a restricted subset of JSON5 — standard JSON plus `//` and `/* */` comments and trailing commas (not the full JSON5 spec: no unquoted keys, no single-quoted strings). Edits are picked up automatically while DockSheath is running — no restart needed.

Note: pinning/unpinning an app from the taskbar UI rewrites the file as plain JSON and will remove any comments you've added — hand-edit comments back in afterward if you'd like to keep them.

## Building from source

Requires Xcode 15+ (or the Swift 5.9+ toolchain) on macOS 13+.

```sh
git clone https://github.com/WentTheFox/MacOSTaskbar.git
cd MacOSTaskbar
open Package.swift        # opens directly in Xcode, or:
swift build                # command-line build
swift test                 # run the JSON5Config / AXWindowKit test suites
Scripts/build_app.sh debug # assemble a runnable DockSheath.app locally
```

## Contributing

The codebase is split into focused Swift Package targets under `Sources/`:

- `DockSheath` — app bootstrap, menu bar item, onboarding
- `DockOverlayKit` — the Dock-covering overlay window and screen-space-reservation geometry
- `AXWindowKit` — window enumeration/control via the Accessibility API
- `JSON5Config` — the restricted-JSON5 parser and config store
- `TaskbarUI` — taskbar chrome, pinned apps, and the quick-launch panel
- `GlobalHotKey` — the systemwide show/hide shortcut

Pull requests welcome. Since DockSheath needs Accessibility access to do anything useful, and ad-hoc code signatures change on every local rebuild, macOS's permission system (TCC) may re-prompt you repeatedly while iterating — using a stable local self-signed code-signing certificate for development builds avoids this (see Apple's documentation on creating a certificate in Keychain Access and set it as your local `codesign` identity instead of `-`).

## Known limitations

- Single-display only for now — the taskbar appears on the main screen (multi-monitor support is planned)
- Not distributed on the Mac App Store (DockSheath runs unsandboxed by necessity, since sandboxed apps can't control other apps' windows via the Accessibility API)
- Window title/content thumbnails are not implemented yet

## License

[MIT](LICENSE)
