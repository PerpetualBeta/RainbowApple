# RainbowApple

A tiny macOS utility that replaces the grey Apple logo in the menu bar with the classic six-colour rainbow Apple logo from 1977.

## Requirements

- macOS 14 (Sonoma) or later

## Installation

Two formats on every release — both signed and notarised, pick whichever suits:

- **[Installer (`.pkg`)](https://github.com/PerpetualBeta/RainbowApple/releases/latest/download/RainbowApple.pkg)** — recommended for first-time installs. Double-click to run; macOS Installer places the app in `/Applications` without quarantine or App Translocation.
- **[Download (`.zip`)](https://github.com/PerpetualBeta/RainbowApple/releases/latest)** — unzip and drag `RainbowApple.app` to your Applications folder.

After installation, launch RainbowApple — the rainbow Apple logo appears over the system Apple icon in the menu bar.


## How It Works

RainbowApple places a small transparent window precisely over the system Apple logo in the top-left corner of the menu bar. The window renders the Apple logo glyph filled with the original six-colour rainbow stripes:

| Stripe | Colour | Hex |
|--------|--------|-----|
| 1 (top) | Green | #61BB46 |
| 2 | Yellow | #FDB827 |
| 3 | Orange | #F5821F |
| 4 | Red | #E03A3E |
| 5 | Purple | #963D97 |
| 6 (bottom) | Blue | #009DDC |

The overlay is click-through — clicking the Apple logo still opens the Apple menu as normal.

## Features

- Appears on all Spaces (follows you as you switch)
- Click-through — does not interfere with the Apple menu
- No dock icon
- Auto-aligns to the system Apple logo on any display — including notched MacBook Pros, whose 24pt menu bars differ from the standard 22pt bar used on external displays and non-notched Macs
- Minimal resource usage

## Settings

Right-click the small Apple icon in the menu bar and choose **Settings…** to configure:

- **Accessibility** — permission status with grant button
- **Menu bar icon pill** — optional grey background for stronger contrast on busy or wallpaper-tinted menu bars (off by default)
- **Launch at Login** — start RainbowApple automatically when you log in

Auto-updates are handled by Sparkle. Use the **Check for Updates…** entry in the right-click menu to check on demand; Sparkle's prompt offers an "Automatically download and install updates in the future" checkbox the first time an update is available.

## Quitting

Right-click the small Apple icon in the menu bar (the status bar item) and choose **Quit RainbowApple**.

## Building from Source

RainbowApple is a single-file Swift app. No Xcode project is required.

```bash
cd ~/Desktop/RainbowApple
./build.sh
open RainbowApple.app
```

The build script compiles `main.swift` with `swiftc`, links against Cocoa, and assembles the `.app` bundle with the app icon.

## Alignment

RainbowApple now auto-scales to the current menu bar height, so alignment should be correct on every display out of the box — external monitors, Studio Display, non-notched MacBooks, and notched MacBook Pros alike. The overlay re-aligns automatically when you plug or unplug a display, change resolution, or move the app between screens.

If you notice a misalignment on an unusual display configuration, the reference constants live at the top of `positionOverlay()` in `main.swift`:

| Constant | Default | Role |
|---|---|---|
| Reference bar height | `22.0` | Point size the other constants were tuned against |
| Apple centre X | `28.5` | Horizontal centre of the system Apple logo on a 22pt bar |
| Vertical nudge | `1.5` | Fine-tune offset relative to menu bar geometric centre |

The live scale factor is `menuBarHeight / 22.0`, and every position is computed from there. Adjusting the reference values is rarely needed — report the mismatch instead.

---

RainbowApple is provided by [Jorvik Software](https://jorviksoftware.cc/). If you find it useful, consider [buying me a coffee](https://jorviksoftware.cc/donate).
