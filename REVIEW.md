# Third-Party Code Review: Auto Brightness (Keyboard + Display)

Summary of existing projects and how **AmbientBrightness** improves on them to automate built-in keyboard and display from ambient light on macOS.

---

## 1. DarkModeBuddy (insidegui) + QMKAmbientBacklight (karlshea)

**Purpose:** DarkModeBuddy switches system light/dark mode from ambient light. QMKAmbientBacklight reuses its sensor code to drive **external** QMK keyboards.

**Ambient light sensor (what we reuse conceptually):**
- **Primary:** BezelServices private framework, `ALCALSCopyALSServiceClient()` then `IOHIDServiceClientCopyEvent(..., kAmbientLightSensorEvent, ...)` and `IOHIDEventGetFloatValue()`. Gives a lux-like value.
- **Fallback:** AppleLMUController via IOKit. `IOConnectCallMethod(port, 0, nil, 0, nil, 0, values, &outputs, nil, 0)` with 2 outputs; lux = `(3 * values[0] / 100000 - 1.5)`, clamped to >= 0.

**Limitation:** QMKAmbientBacklight only sends values to QMK firmware; it does not control built-in MacBook keyboard or display.

---

## 2. LightKit (maxmouchet) – archived 2020

**Purpose:** Swift library for ambient sensor, display brightness, and **keyboard** brightness on MacBook.

**Implementation (all in one `LightKit.swift`):**
- **LMU:** Single connection to `AppleLMUController`:
  - Selector 0: get sensor (2 scalar outputs) – left/right as raw/2000.
  - Selector 1: get LED brightness (1 input 0, 1 output) – value/0xfff = 0...1.
  - Selector 2: set LED brightness (2 inputs: 0, value*0xfff; 1 output).
- **Display:** `IOServiceGetMatchingServices(IODisplayConnect)` then `IODisplayGetFloatParameter` / `IODisplaySetFloatParameter` with `kIODisplayBrightnessKey`.

**Limitations:**
- Archived; not maintained. Fails on 2016+ Touch Bar and many Apple Silicon Macs for **keyboard** (LMU keyboard API reportedly removed/restricted).
- Display path (IODisplay*) still works on most Macs with built-in display.
- No automation loop or UI; library only.

---

## 3. kbdlight (WhyNotHugo)

**Purpose:** CLI to set MacBook keyboard backlight level.

**Implementation:** Uses Linux sysfs paths (`/sys/class/leds/smc::kbd_backlight/...`). **macOS version is different** – the repo’s single `kbdlight.c` is Linux-only. So for macOS we cannot reuse this; we use IOKit/LMU or CoreBrightness instead.

---

## 4. lightum (poliva)

**Purpose:** Daemon to auto-adjust keyboard and screen backlight from ambient sensor.

**Implementation:** Linux-only (Ubuntu on MacBook hardware). Reads from sysfs, uses X11/ConsoleKit for idle. Not applicable to macOS.

---

## 5. mac-brightnessctl (rakalex)

**Purpose:** CLI to control display and keyboard brightness on Mac.

**Implementation:**
- **Display:** IOKit/BrightnessControl (similar to IODisplay approach).
- **Keyboard:** Loads private **CoreBrightness.framework** and uses class `KeyboardBrightnessClient` (e.g. `setBrightness:forKeyboard:`, `brightnessForKeyboard:`). Works on some newer Macs where LMU keyboard control does not.

**Limitation:** No ambient light loop; CLI only. Keyboard control depends on private framework availability.

---

## Improvements in AmbientBrightness

| Area | Third-party state | Our approach |
|------|-------------------|--------------|
| **Sensor** | DarkModeBuddy/QMK: BezelServices + LMU fallback. LightKit: LMU only (scalar method 0, 2 outputs). | Use **LMU-only** path in Swift (no BezelServices) so one codebase, one connection. Map sensor reading to 0...1 ambient level (average if two channels). |
| **Display** | LightKit/mac-brightnessctl: IODisplayConnect + IODisplay*Parameter. | Same; works on all Macs with built-in display. |
| **Keyboard** | LightKit: LMU scalar 1/2. mac-brightnessctl: CoreBrightness. | Use **LMU** first (same connection as sensor). If set/get fails or returns nil, disable keyboard automation and show “Keyboard not supported on this Mac.” Optional future: CoreBrightness bridge for supported models. |
| **Automation** | None of the above run a continuous “sensor -> display + keyboard” loop with configurable mapping. | **Timer-based loop:** read sensor, map ambient 0...1 to display 0...1 and keyboard 0...1 with configurable **min/max** and optional curve. Only update when value changes beyond a small threshold to avoid flicker. |
| **UI** | QMKAmbientBacklight has SwiftUI settings; others are CLI or library. | **Menu bar app:** enable/disable, adjust display min/max, keyboard min/max, poll interval, “launch at login.” |
| **Compatibility** | LightKit broken on 2016+ / Apple Silicon for keyboard. | Graceful degradation: display-only when keyboard control unavailable; clear status in UI. |

---

## Technical notes

- **LMU sensor:** LightKit uses `IOConnectCallScalarMethod` with selector 0, 0 inputs, 2 outputs; values/2000 = 0...1. QAB legacy uses `IOConnectCallMethod` (not Scalar) with 2 outputs and a different formula. We use the **scalar** API and treat (left+right)/2 as ambient level 0...1 for mapping.
- **Display:** Iterate `IODisplayConnect` services; use first or primary; set/get `kIODisplayBrightnessKey` (float 0...1). Release each service after use.
- **Keyboard:** Scalar method 1 (get) with input [0]; scalar method 2 (set) with inputs [0, UInt64(brightness * 0xfff)]. Allocate output buffer for actual output count (LightKit’s single-element allocation is wrong for 2-output sensor; we fix that).
- **Privacy / App Store:** Uses IOKit and possibly private LMU selectors. Not suitable for App Store; distribute outside or open source.

---

## References

- DarkModeBuddy: https://github.com/insidegui/DarkModeBuddy  
- QMKAmbientBacklight: https://github.com/karlshea/QMKAmbientBacklight  
- LightKit: https://github.com/maxmouchet/LightKit  
- kbdlight: https://github.com/WhyNotHugo/kbdlight  
- lightum: https://github.com/poliva/lightum  
- mac-brightnessctl: https://github.com/rakalex/mac-brightnessctl  
