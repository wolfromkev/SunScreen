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

## Build

```bash
git clone https://github.com/wolfromkev/SunScreen.git
cd SunScreen
bash build.sh
```

This compiles the Swift and C sources, creates a signed `.app` bundle in `build/`, and prints instructions for running or installing.

## Run

```bash
open build/SunScreen.app
```

## Install

Copy to Applications for permanent use:

```bash
cp -r build/SunScreen.app /Applications/
```

Then launch SunScreen from Spotlight or the Applications folder. Click the sun icon in your menu bar to open the controls.

## How It Works

| Layer | Technology |
|-------|-----------|
| Brightness | Apple DisplayServices (private framework, same as keyboard keys) with IOKit fallback |
| Color temperature | `CGSetDisplayTransferByFormula` — adjusts per-channel gamma curves |
| Kelvin → RGB | Tanner Helland's color temperature algorithm |
| Darkroom mode | Red-only gamma (green and blue channels zeroed) |
| UI | SwiftUI popover hosted in an AppKit `NSStatusItem` |
| Scheduling | 60-second timer with smooth interpolation across a 60-minute transition window |

## Project Structure

```
SunScreen/
├── Sources/
│   ├── main.swift              # App entry point
│   ├── AppDelegate.swift       # Menu bar setup, popover, wake observer
│   ├── BrightnessManager.swift # Swift wrapper around C brightness helper
│   ├── BlueLightManager.swift  # Kelvin → gamma conversion, darkroom mode
│   ├── ScheduleManager.swift   # Auto scheduling, persistence, system sync
│   ├── ContentView.swift       # SwiftUI popover UI
│   ├── brightness_helper.c     # IOKit + DisplayServices brightness control
│   └── brightness_helper.h     # C header for Swift bridging
├── Resources/
│   ├── Info.plist              # App bundle config (LSUIElement for menu bar)
│   ├── AppIcon.icns            # App icon
│   └── AppIcon.png             # Source icon image
├── build.sh                    # Build script
└── README.md
```

## License

MIT
