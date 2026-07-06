# DockSheath

[![Build](https://github.com/WentTheFox/MacOSTaskbar/actions/workflows/build.yml/badge.svg)](https://github.com/WentTheFox/MacOSTaskbar/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

A free, open-source, native Windows-style taskbar for macOS — a FOSS alternative to uBar and similar Dock replacements. DockSheath docks at the bottom of the screen, lists and manages running app windows, and adds a pinned quick-launch strip with a menu for jumping straight to any pinned app.

The project name is inspired by the concept of hiding the dock when not needed (like sheathing a sword), while also being a reflecton of my personal opinion of MacOS when read aloud quickly. To some, it may also be their opinion of a purely vibe-coded project, which this very much is.

## How it works

Unlike apps that try to hide or replace the real macOS Dock, **DockSheath leaves the Dock running** and simply draws its own taskbar on top of it, covering it visually. Because the real Dock is still present on whichever edge of the screen it occupies, macOS itself reserves that space in `NSScreen.visibleFrame` — so double-clicking a window's title bar to maximize just works, with no windows getting cut off behind the taskbar, and no private APIs involved.

DockSheath follows the Dock to wherever it is — bottom, left, or right — laying itself out horizontally at the bottom or vertically on the side to match. If the Dock is set to **auto-hide**, there's no reserved space to cover (macOS treats an auto-hidden Dock's hover-reveal as a temporary overlay, not a layout change), so DockSheath mirrors it instead: hidden until the mouse reaches that edge, hidden again shortly after it moves away. If DockSheath can't find the Dock reserving space or auto-hidden on any edge at all, it warns you from its menu bar item.

Need the real Dock for something DockSheath doesn't replicate (Trash, Launchpad, right-click Dock menus)? Hide the DockSheath taskbar instantly from the menu bar item or a configurable global hotkey (default `⌘⌥D`) to reveal it underneath.

With `behavior.showOnAllDisplays` enabled, DockSheath also renders a taskbar on every other connected screen. The real Dock only ever occupies one screen, so macOS reserves no space at all on the others — DockSheath compensates by actively watching for windows that get placed under its taskbar there and resizing them to sit above it instead.

## Features

- Taskbar docked to whichever screen edge the Dock is on (bottom, left, or right) with genuine screen-space reservation
- Running windows grouped by app by default — click to activate/minimize, right-click to close, middle-click to launch another instance of the app, with each button's label showing that window's title (or "AppName (N)" plus a tooltip listing every title when an app has several windows); set `behavior.groupWindowsByApp` to `false` in config for one button per window instead
- Pinned "quick launch" apps strip in its own fixed zone ahead of running windows — a pin stays icon-only (no label) until you open it, then its button merges with that app's running-window button in place, so new windows attach to the pinned icon instead of appearing separately
- The Start button opens a searchable Quick Launch menu listing every installed app — type to filter live, arrow keys/Return to navigate and launch, click an app's star to pin it to the top of the list (independent of the taskbar strip's own pins), plus "Manage Pinned Apps…" to edit the strip
- Pin a running app straight from its right-click menu (alongside Minimize/Close), or unpin from a pinned app's own right-click menu — no need to dig through Settings for the common case
- Hand-editable JSON5 configuration (comments + trailing commas supported), live-reloaded on save — or use the native **Settings…** window for the same config without hand-editing
- Taskbar and button colors follow the system light/dark appearance by default, with per-element background/border/text overrides available in config
- Toggle the taskbar via menu bar item or global hotkey to reveal the real Dock underneath
- Optional taskbar on every other connected display too (`behavior.showOnAllDisplays`) — those screens have no real Dock reserving space for it, so DockSheath actively keeps windows there from sitting underneath it; each display's taskbar only shows the windows actually open on it (falling back to the main display for a window whose screen can't be determined), and the pinned-apps strip only ever appears on the main display
- Optional display-number badge and formatted clock at the trailing edge of each taskbar (`appearance.showDisplayNumber`, `appearance.clock`)
- Secondary-display taskbars can override taskbar size and appearance independently (`secondaryDisplay`), inheriting anything left unset from the main config

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

To pull the latest changes and rebuild an existing install in one step, run `Scripts/update.sh` (defaults to `/Applications`, or pass a different install directory). It quits the running app if needed, replaces the installed `.app`, and clears the quarantine attribute (`xattr -cr`) on the newly built binary so Gatekeeper doesn't block it.

Before building, `update.sh` also checks your login keychain for a local code-signing certificate named `DockSheath Local Signing` and signs the build with it. This keeps your Accessibility/Screen Recording grant working across rebuilds — see [Permissions](#permissions) below for why, and how to create that certificate. If the certificate isn't there yet, the script prints setup instructions and pauses, waiting for a keypress before it re-checks and continues — no need to re-run it, just create the certificate and press any key.

## Permissions

On first launch, DockSheath walks you through granting **Accessibility** access (System Settings → Privacy & Security → Accessibility). This is required for the taskbar to see and control other apps' windows. If you grant access after DockSheath is already running, you may need to quit and relaunch it for the grant to take effect — this is a general macOS quirk, not specific to DockSheath.

### Keeping that grant across rebuilds

macOS's permission system (TCC) ties the Accessibility grant to the app's code signature, not just its bundle identifier. A plain ad-hoc signature (the default for an unsigned local build) is derived from the binary's own contents, so it changes on every rebuild — TCC then treats the rebuilt app as a different, ungranted app, and you'd otherwise have to remove and re-add it in System Settings after every single build.

`Scripts/update.sh` avoids this by signing with a stable local self-signed certificate instead, so the identity stays the same across rebuilds and the grant carries over. To set it up once:

1. Open Keychain Access (Applications → Utilities → Keychain Access)
2. Keychain Access menu → Certificate Assistant → Create a Certificate...
3. Name it `DockSheath Local Signing`, set Identity Type to "Self Signed Root" and Certificate Type to "Code Signing"
4. Click Create, then Done

`update.sh` will detect and use it automatically from then on (pass a different name via the `DOCKSHEATH_CODESIGN_IDENTITY` environment variable if you'd rather call it something else). This is local-machine setup only — the certificate isn't part of the repo, and building via `Scripts/build_app.sh` directly (or from Xcode) without a signing identity still produces the same ad-hoc-signed build as before.

## Configuration

DockSheath stores its config at:

```
~/.config/docksheath/config.json5
```

A commented default is generated on first run. It supports the full [JSON5 spec](https://spec.json5.org) — comments, trailing commas, unquoted keys, single-quoted strings, and more. Edits are picked up automatically while DockSheath is running — no restart needed.

Most of the config below can also be edited from **Settings…** in the menu bar item — a native window covering behavior, appearance (theme, colors, icon size, the display-number badge, and the clock), secondary-display overrides, the show/hide hotkey (with a click-to-record shortcut field), and pinned apps. It reads and writes the same `config.json5`, so hand-editing still works for anything not yet exposed there, and either way of editing is picked up live by the other.

Note: pinning/unpinning an app (from the taskbar UI or from Settings) rewrites the file as plain JSON and will remove any comments you've added — hand-edit comments back in afterward if you'd like to keep them.

### Display-number badge and clock

Setting `appearance.showDisplayNumber` to `true` shows a small badge with the screen's number (matching the order in System Settings → Displays) at the trailing edge of its taskbar — handy for telling secondary-display taskbars apart at a glance.

`appearance.clock` adds an optional clock next to it:

```json5
"clock": {
  "enabled": true,
  "format": "h:mm a", // -> "3:45 PM"
},
```

`format` uses [`DateFormatter`'s pattern syntax](https://unicode-org.github.io/icu/userguide/format_parse/datetime/#date-field-symbol-table) (Unicode TR35). A few common tokens:

| Token | Meaning | Example |
| --- | --- | --- |
| `h` / `H` | hour, 12h / 24h | `3` / `15` |
| `mm` | minute, zero-padded | `45` |
| `ss` | second, zero-padded | `09` |
| `a` | AM/PM | `PM` |
| `EEE` | weekday, short | `Tue` |
| `MMM` | month, short | `Jul` |
| `d` | day of month | `3` |

Some example formats:

| `format` | Renders as |
| --- | --- |
| `h:mm a` | `3:45 PM` |
| `HH:mm` | `15:45` |
| `h:mm a EEE` | `3:45 PM Tue` |
| `M/d/yy h:mm a` | `7/3/26 3:45 PM` |

### Fonts

`appearance.buttonFont`, `appearance.displayNumberFont`, and `appearance.clockFont` control the font used by taskbar buttons (Start, pinned apps, running windows), the display-number badge, and the clock, respectively — independently of each other and of the taskbar's own thickness (`taskbar.sizeOverride`):

```json5
"buttonFont": { "family": "Menlo", "size": 11 },
"displayNumberFont": { "family": "Menlo", "size": 10 },
"clockFont": { "family": "Menlo", "size": 11 },
```

`family` is a font **family** name (e.g. `"Avenir Next"`), not a PostScript name — `null`, omitted, or a name that doesn't match an installed family all fall back to the system font. `size` is in points; defaults are 11/10/11 respectively, matching the look before these settings existed. Each element's font weight (regular for buttons, bold for the display number, medium for the clock) is fixed and not configurable.

### Secondary-display overrides

When `behavior.showOnAllDisplays` is enabled, the `secondaryDisplay` section lets those taskbars differ from the main one. Any field you set under `secondaryDisplay.taskbar`/`secondaryDisplay.appearance` overrides the matching field in `taskbar`/`appearance`; anything left `null`/omitted inherits the main config's value. The primary display (the one the real Dock is on) always uses `taskbar`/`appearance` directly and ignores this section.

```json5
"secondaryDisplay": {
  "taskbar": {
    "sizeOverride": 40,
  },
  "appearance": {
    "theme": "dark",
    "showDisplayNumber": true,
    "clock": { "enabled": true, "format": "HH:mm" },
    "buttonFont": { "family": "Menlo", "size": 11 },
    "displayNumberFont": { "family": "Menlo", "size": 10 },
    "clockFont": { "family": "Menlo", "size": 11 },
  },
},
```

## Contributing

The codebase is split into focused Swift Package targets under `Sources/`:

- `DockSheath` — app bootstrap, menu bar item, onboarding, and the Settings window
- `DockOverlayKit` — the Dock-covering overlay window and screen-space-reservation geometry
- `AXWindowKit` — window enumeration/control via the Accessibility API
- `JSON5Config` — the JSON5 parser and config store
- `TaskbarUI` — taskbar chrome, pinned apps, and the Quick Launch menu
- `GlobalHotKey` — the systemwide show/hide shortcut

Run `swift test` to run the `JSON5Config`/`AXWindowKit` test suites.

Pull requests welcome. Since DockSheath needs Accessibility access to do anything useful, and ad-hoc code signatures change on every local rebuild, macOS's permission system (TCC) may re-prompt you repeatedly while iterating if you're building directly via `swift build`/`Scripts/build_app.sh` rather than `Scripts/update.sh` — see [Keeping that grant across rebuilds](#keeping-that-grant-across-rebuilds) for the one-time certificate setup that avoids this.

## Known limitations

- Not distributed on the Mac App Store (DockSheath runs unsandboxed by necessity, since sandboxed apps can't control other apps' windows via the Accessibility API)
- Window content thumbnails/previews are not implemented yet
- The real Dock's own hover tooltips can still appear while it's covered by the taskbar. DockSheath's overlay window does correctly intercept mouse events for its own buttons (it isn't click-through), so this points to the Dock using its own cursor-position tracking that isn't gated by window occlusion — there's no public API to suppress another app's UI, so this isn't something DockSheath can fix
- On secondary displays (`showOnAllDisplays`), windows that drift under the taskbar are pulled back above it on a ~1s poll rather than instantly, since there's no lightweight per-window move/resize notification available without a heavier per-window `AXObserver`

## License

[MIT](LICENSE)
