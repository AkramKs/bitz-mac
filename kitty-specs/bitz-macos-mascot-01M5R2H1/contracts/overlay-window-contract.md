# Contract: macOS Desktop Overlay Window (`MascotOverlayPanel`)

**Mission**: `bitz-macos-mascot-01M5R2H1`  
**Component**: `src/App/Window/MascotOverlayPanel.swift`

---

## 1. `NSPanel` Property Invariants

`MascotOverlayPanel` MUST initialize and maintain these exact AppKit window properties:

| Property / Method | Required Value | Rationale |
| :--- | :--- | :--- |
| `styleMask` | `[.nonactivatingPanel, .borderless]` | Removes window chrome and prevents activating the app when shown. |
| `level` | `.floating` | Keeps Bitz visible above normal application windows. |
| `isOpaque` | `false` | Enables per-pixel alpha transparency. |
| `backgroundColor` | `.clear` | Eliminates rectangular window background fill. |
| `hasShadow` | `false` | Prevents rectangular drop-shadow artifacts around the transparent frame. |
| `isMovableByWindowBackground` | `false` | Locks Bitz in its designated desktop anchor position. |
| `ignoresMouseEvents` | `true` | **Mandatory (`PROJECT_002`)**: Passes 100% of mouse clicks and hovers to underlying windows. |
| `collectionBehavior` | `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` | Appears across all Mission Control Spaces and alongside full-screen apps. |
| `canBecomeKey` | `false` | Never steals keyboard focus from the active app. |
| `canBecomeMain` | `false` | Never becomes the main window. |

---

## 2. Geometry & Screen Placement Contract

- **Default Mascot Canvas Size**: `250 x 250` points (`CGSize(width: 250, height: 250)`).
- **Bottom-Right Anchor Formula**:
  Given `screenRect = NSScreen.main?.visibleFrame`:
  - `origin.x = screenRect.maxX - 270` (`250` pt width + `20` pt right margin)
  - `origin.y = screenRect.minY + 20` (`20` pt bottom margin above the macOS Dock)
- **Wallpaper Non-Interference (`PROJECT_002`)**:
  - `MascotOverlayPanel` and all application modules MUST NOT call `NSWorkspace.shared.setDesktopImageURL(_:for:options:)` or any wallpaper-mutating API.
