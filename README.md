# AmbientBrightness

A macOS menu bar app that automatically adjusts **display** and **keyboard** brightness based on your Mac’s ambient light sensor.

**Themes:** macOS apps and tweaks — uses IOKit, BezelServices, and CoreBrightness to control built-in hardware from the menu bar.

## Features

- **Display brightness** — Automatically dims or brightens the built-in display from ambient light.
- **Keyboard backlight** — When supported (LMU or CoreBrightness), adjusts the keyboard backlight too.
- **Sensor support** — Uses Apple LMU (older Macs) or BezelServices HID (e.g. MacBook Air M4) for the ambient sensor.
- **Launch at login** — Optional (macOS 13+).
- **Configurable** — Min/max ranges and poll interval in Settings.

## Requirements

- macOS 12 or later
- Mac with a built-in ambient light sensor (e.g. MacBook, MacBook Air, MacBook Pro)

Keyboard backlight control is only available on some models; on others the app runs in display-only mode.

## Build and run

1. Open `AmbientBrightness.xcodeproj` in Xcode.
2. Build and run (Cmd+R), or build from the command line:
   ```bash
   xcodebuild -scheme AmbientBrightness -configuration Debug build
   ```
3. The app runs from the menu bar (sun icon). Use **Settings...** to configure, **Start automation** to begin.

## License

See [LICENSE](LICENSE) if present. Third-party approaches used are credited in [REVIEW.md](REVIEW.md).
