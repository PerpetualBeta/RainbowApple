# RainbowApple

A tiny macOS utility that replaces the grey Apple logo in the menu bar with the classic six-colour rainbow Apple logo from 1977.

## Requirements

- macOS 12 (Monterey) or later

## Installation

1. Double-click `RainbowApple.app` to launch it
2. The rainbow Apple logo appears over the system Apple icon in the menu bar

Since RainbowApple is an unsigned app, macOS may block it on first launch. If this happens:
- Right-click `RainbowApple.app` and choose **Open**, then click **Open** again in the dialog
- Or go to **System Settings → Privacy & Security** and click **Open Anyway**

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
- Adjusts position automatically on screen resolution changes
- Minimal resource usage

## Quitting

Click the small Apple icon in the right side of the menu bar (the status bar item) to reveal the **Quit RainbowApple** option.

## Starting at Login

To have RainbowApple launch automatically, add it to **System Settings → General → Login Items**.

## Building from Source

RainbowApple is a single-file Swift app. No Xcode project is required.

```bash
cd ~/Desktop/RainbowApple
./build.sh
open RainbowApple.app
```

The build script compiles `main.swift` with `swiftc`, links against Cocoa, and assembles the `.app` bundle with the app icon.

## Tuning

If the rainbow logo doesn't align perfectly with the system Apple icon on your display, you can adjust these values in `main.swift`:

| Value | Line | Purpose |
|-------|------|---------|
| `fontSize` | 13 | Size of the Apple logo glyph |
| `appleCentreX` | 112 | Horizontal position (points from left edge) |
| `y + 1.5` | 114 | Vertical offset from menu bar centre |

After editing, run `./build.sh` to recompile.

---

RainbowApple is part of [Jorvik Software](https://jorviksoftware.cc/). If you find it useful, consider [buying me a coffee](https://jorviksoftware.cc/donate).
