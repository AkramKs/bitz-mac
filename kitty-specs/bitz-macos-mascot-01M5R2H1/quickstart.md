# Quickstart: Bitz the Cyber Cat (`bitz-mac`)

**Mission**: `bitz-macos-mascot-01M5R2H1`  
**Target Platform**: macOS 14.0+ (Sonoma or newer), Swift 6

---

## 1. Prerequisites

- macOS 14.0+ (Apple Silicon or Intel)
- Xcode 16+ / Swift 6 toolchain (`swift --version`)

## 2. Build the Project

From the repository root (`/Users/akramkasimi/Documents/bitz-mac`):

```bash
swift build
```

## 3. Run Automated Unit Tests

Run the full test suite (`WellnessPointEngine`, `ActivityMonitorService`, `MascotOverlayPanel`, and `MascotOverlayView` Rive bridge tests):

```bash
swift test
```

## 4. Run the Desktop Companion

Launch the Bitz desktop companion executable:

```bash
swift run BitzApp
```

When launched:
- Bitz appears in the bottom-right corner above your macOS Dock (`250x250` pt transparent `MascotOverlayPanel`).
- All mouse clicks pass directly through Bitz to the windows underneath (`ignoresMouseEvents == true`).
- Your desktop wallpaper remains completely untouched.
- If `bitz_mascot.riv` is placed in the bundle resources, `MascotOverlayView` drives the Rive `BitzStateMachine`; otherwise, it automatically renders the high-craft vector fallback using the exact same `BitzStateMachine` state inputs.
