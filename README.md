# SunScreen

A lightweight macOS menu bar app that automatically adjusts screen brightness and color temperature throughout the day — like [f.lux](https://justgetflux.com/), built from scratch in Swift.

## Features

- **Hardware brightness control** — Uses Apple's DisplayServices framework (the same API your keyboard brightness keys use) for true backlight adjustment
- **Blue light filter** — Kelvin-based color temperature control (1200K–6500K) using accurate gamma curves via the Tanner Helland algorithm
- **Automatic scheduling** — Smoothly transitions between day and night settings based on your configured sunrise/sunset times
- **Darkroom mode** — Red-only display output to preserve night vision
- **Presets** — One-click Daylight (6500K), Halogen (3400K), Incandescent (2700K), Candle (1900K), and Ember (1200K)
- **System sync** — Polls actual display brightness every 2 seconds so the slider stays in sync with keyboard keys and Control Center
- **Menu bar only** — No Dock icon, just a sun icon in your menu bar
- **Persists settings** — All preferences saved automatically via UserDefaults

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode Command Line Tools

## Build & Install

```bash
git clone https://github.com/wolfromkev/SunScreen.git
cd SunScreen
bash install.sh
```

This compiles the Swift sources with SPM, creates a signed `.app` bundle, and installs it to `/Applications/`.

## Run

```bash
open /Applications/SunScreen.app
```

Click the sun icon in your menu bar to open the controls.

## Build Only (no install)

```bash
bash build.sh
open build/SunScreen.app
```

## How It Works

| Layer | Technology |
|-------|-----------|
| Brightness | Apple DisplayServices (private framework, same as keyboard keys) with IOKit fallback |
| Color temperature | `CGSetDisplayTransferByFormula` — adjusts per-channel gamma curves |
| Kelvin → RGB | Tanner Helland's color temperature algorithm |
| Darkroom mode | Red-only gamma (green and blue channels zeroed) |
| UI | SwiftUI view hosted in an AppKit `NSMenu` attached to `NSStatusItem` |
| Scheduling | 60-second timer with smooth interpolation across a 60-minute transition window |

## Project Structure

```
SunScreen/
├── Sources/
│   └── SunScreen/
│       └── main.swift            # All app code in a single file
├── Resources/
│   ├── Info.plist                # App bundle config (LSUIElement for menu bar)
│   ├── AppIcon.icns              # App icon
│   └── AppIcon.png               # Source icon image
├── Package.swift                 # Swift Package Manager config
├── build.sh                      # Build script
├── install.sh                    # Build + install to /Applications
└── README.md
```

## License

MIT
