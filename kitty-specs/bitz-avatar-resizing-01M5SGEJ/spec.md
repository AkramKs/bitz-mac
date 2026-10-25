# Mission Specification: Manual Avatar Resizing & Scale Persistence

**Mission Branch**: `feat/bitz-avatar-resizing`  
**Mission Slug**: `bitz-avatar-resizing-01M5SGEJ`  
**Mission ID**: `01M5SGEJ4JNF33A7ZE06VWG472`  
**Created**: 2026-10-25  
**Status**: Approved  
**Input**: Allow users to manually resize the Bitz desktop companion avatar as the fixed `250×250` pt size can be too big or too small for specific users and display configurations.

---

## Overview & Product Vision

**Bitz the Cyber Cat** floats in the bottom-right corner of the user's active screen inside a borderless, transparent, click-through `NSPanel` (`MascotOverlayPanel`). Previously, both `MascotOverlayPanel` and `MascotOverlayView` were locked to a static `250×250` pt canvas (`MascotOverlayPanel.defaultPanelSize`). On compact 13-inch laptop displays with dense IDE windows, `250×250` pt can feel too large; on high-resolution 27-inch to 49-inch external monitors, `250×250` pt can feel too small to read Bitz's LED visor expressions, thermal alerts, and telemetry pill at a glance.

Because `MascotOverlayPanel` enforces unconditional click-through windowing (`ignoresMouseEvents == true`, `DIR-001`, `C-002`) so desktop clicks are never intercepted, manual resizing is provided through the macOS Menu Bar status item (`BitzMenuBarContentView`). Users can resize Bitz at any time using curated **size presets** (`Small 60%`, `Medium 80%`, `Default 100%`, `Large 125%`, `XL 150%`) or **fine-grained step buttons** (`-10%`, `+10%`, `Reset 100%`) bounded between `50%` (`0.50x`, `125×125` pt) and `175%` (`1.75x`, `437.5×437.5` pt).

Whenever the user adjusts the size:
1. `MascotOverlayPanel` proportionally scales its window frame (`250 * scaleFactor` × `250 * scaleFactor` pt) and re-anchors its origin to the bottom-right corner of `NSScreen.main?.visibleFrame` (`maxX - scaledWidth - 20`, `minY + 20`).
2. `MascotOverlayView` proportionally scales the entire `250×250` cyberpunk mascot composition (ears, head, LED visor, body/loaf posture, tail, speech bubble, and hardware telemetry pill) without clipping or aspect-ratio distortion.
3. The selected scale factor is persisted in `UserDefaults` (`"avatarScaleFactor"`) and automatically restored across app restarts and display reconfiguration events.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Menu Bar Avatar Size Presets & Step Controls (Priority: P1)

As a macOS user whose screen makes the default `250×250` pt mascot feel too large or too small, I want manual resize controls in the Bitz Menu Bar menu—including one-click size presets (`Small 60%`, `Medium 80%`, `Default 100%`, `Large 125%`, `XL 150%`) and `+/- 10%` step adjustment buttons—so that I can tailor Bitz's size to my workspace while keeping the desktop overlay 100% click-through.

**Why this priority**: Gives users immediate, deterministic manual control over Bitz's footprint without violating the click-through overlay invariant (`DIR-001`).

**Independent Test**: Exercise the avatar scale model/controller and `BitzMenuBarContentView` actions across all presets (`0.60`, `0.80`, `1.00`, `1.25`, `1.50`), step increments (`+0.10`), step decrements (`-0.10`), and reset (`1.00`), verifying exact scale calculations, two-decimal rounding, and boundary clamping within `0.50...1.75`.

**Acceptance Scenarios**:

1. **Given** Bitz is running at default scale (`1.00` / `100%`), **When** the user opens the Menu Bar menu and selects a preset (`Small (60%)`, `Medium (80%)`, `Default (100%)`, `Large (125%)`, or `XL (150%)`), **Then** the active scale factor immediately updates to `0.60`, `0.80`, `1.00`, `1.25`, or `1.50` respectively, and the menu displays the current percentage and point dimensions (e.g., `Avatar Size: 80% (200×200 pt)`).
2. **Given** Bitz is at `1.00` (`100%`), **When** the user clicks `Smaller (-10%)`, **Then** the scale factor decreases by `0.10` to `0.90` (`90%`, `225×225` pt); **When** the user clicks `Larger (+10%)`, **Then** the scale factor increases by `0.10` back to `1.00` (`100%`, `250×250` pt).
3. **Given** Bitz is at the minimum scale `0.50` (`50%`, `125×125` pt) or maximum scale `1.75` (`175%`, `437.5×437.5` pt), **When** the user attempts to step further out of bounds (`-10%` at `0.50` or `+10%` at `1.75`), **Then** the scale factor remains clamped within `0.50...1.75` and the corresponding boundary step button is disabled or no-ops cleanly.
4. **Given** Bitz has been resized to any non-default scale (e.g., `0.70` or `1.40`), **When** the user clicks `Reset Size (100%)` in the Menu Bar menu, **Then** the scale factor resets to `1.00` (`250×250` pt).

---

### User Story 2 - Proportional Panel & Canvas Scaling with Bottom-Right Anchoring (Priority: P1)

As a macOS user resizing Bitz, I want both the `MascotOverlayPanel` window frame and the `MascotOverlayView` artwork (cyber-cat silhouette, LED visor, speech bubble, and telemetry pill) to scale proportionally around the `250×250` base layout while remaining anchored `20 pt` from the bottom and right edges of my active screen's `visibleFrame`, so that Bitz never clips, distorts, or drifts away from the bottom-right corner.

**Why this priority**: Scaling the artwork without resizing and re-anchoring the `NSPanel` would either clip Bitz when enlarged (`> 100%`) or leave large invisible margins / push Bitz away from the screen corner when shrunk (`< 100%`).

**Independent Test**: Invoke `MascotOverlayPanel` geometry and resize methods across multiple `scaleFactor` values (`0.50`, `0.60`, `0.80`, `1.00`, `1.25`, `1.50`, `1.75`) and mock `visibleFrame` rectangles, verifying that `panel.frame.size` equals `(250 * scaleFactor, 250 * scaleFactor)`, `panel.frame.origin` equals `(visibleFrame.maxX - scaledWidth - 20, visibleFrame.minY + 20)`, and `MascotOverlayView` applies proportional scaling without clipping.

**Acceptance Scenarios**:

1. **Given** a screen `visibleFrame` of `(x: 0, y: 50, width: 1440, height: 825)` and `scaleFactor = 0.60` (`Small`), **When** `MascotOverlayPanel` updates its size and position, **Then** its panel size is `150×150` pt and its origin is `(1440 - 150 - 20, 50 + 20) == (1270, 70)`.
2. **Given** the same `visibleFrame` and `scaleFactor = 1.50` (`XL`), **When** `MascotOverlayPanel` updates its size and position, **Then** its panel size is `375×375` pt and its origin is `(1440 - 375 - 20, 50 + 20) == (1045, 70)`.
3. **Given** `MascotOverlayView` renders at any `scaleFactor` in `0.50...1.75`, **When** Bitz transitions between states (including `.burnout` loaf posture, `.overheating` speech bubble, and hardware telemetry pill), **Then** the entire `250×250` base canvas scales uniformly by `scaleFactor` inside the `scaledWidth × scaledHeight` frame with zero clipping of ears, tail, speech bubble, or telemetry pill.
4. **Given** Bitz is set to a custom `scaleFactor` (e.g., `1.25`), **When** `NSApplication.didChangeScreenParametersNotification` fires (due to monitor connection, resolution change, or Dock resize), **Then** `MascotOverlayPanel` recalculates its bottom-right origin using the active `1.25` scale (`312.5×312.5` pt) rather than reverting to `250×250` pt.

---

### User Story 3 - Persistent UserDefaults Scale Storage Across Launches (Priority: P2)

As a macOS user, I want my selected avatar size to persist automatically in `UserDefaults` and be applied as soon as Bitz launches, so that Bitz remembers my preferred size across app restarts and system reboots.

**Why this priority**: Without persistence, users whose screens require a smaller or larger avatar would be forced to manually resize Bitz on every launch.

**Independent Test**: Instantiate the scale configuration / `BitzAppDelegate` with an isolated `UserDefaults` suite, set `scaleFactor` to `0.80`, recreate the delegate/panel using the same `UserDefaults` suite, and verify the restored `scaleFactor` is `0.80` and the initial `MascotOverlayPanel` frame size is `200×200` pt.

**Acceptance Scenarios**:

1. **Given** a fresh installation where `UserDefaults` has no stored `"avatarScaleFactor"` value, **When** Bitz launches, **Then** `scaleFactor` defaults to `1.00` (`250×250` pt).
2. **Given** the user changes Bitz's size to `1.25` (`Large 125%`), **When** Bitz quits and relaunches, **Then** `BitzAppDelegate.setupOverlayPanel()` reads `1.25` from `UserDefaults` and initializes `MascotOverlayPanel` and `MascotOverlayView` at `312.5×312.5` pt in the bottom-right corner.
3. **Given** `UserDefaults` contains an invalid or out-of-bounds `"avatarScaleFactor"` (e.g., `0.20`, `4.00`, `-1.0`, or `NaN`), **When** Bitz loads the persisted setting, **Then** values `<= 0` or non-finite fall back to `1.00` and positive out-of-range values clamp strictly to `0.50...1.75`.

---

### Edge Cases

- **Floating-Point Precision on Repeated Step Adjustments**: Repeatedly applying `+0.10` or `-0.10` steps (e.g., `1.00 -> 0.90 -> 0.80 -> 0.70 -> 0.60`) must round to the nearest hundredth (`(value * 100).rounded() / 100`) so binary floating-point drift (such as `0.7999999999999999`) never causes preset checkmark mismatches or jittery frame dimensions.
- **Step Adjustments From Quarter-Step Presets (`125%` / `1.25x`)**: Selecting `Large (125%)` and clicking `+10%` yields `135%` (`1.35x`); clicking `+10%` four more times reaches `175%` (`1.75x`, clamped). Clicking `-10%` from `125%` yields `115%` (`1.15x`).
- **Constrained Visible Screen Frame Guard**: If an unusually small screen or large Dock produces a `visibleFrame` where `250 * scaleFactor` would exceed available width or height (`visibleFrame.width - 40` or `visibleFrame.height - 40`), `MascotOverlayPanel` clamps the effective rendered panel dimension to fit within `visibleFrame` with `20 pt` margins so the panel never extends off-screen or overlaps the menu bar.
- **Preservation of WindowServer Invariants During Live Resize**: Updating `MascotOverlayPanel`'s frame and `NSHostingView`'s frame at runtime must preserve `ignoresMouseEvents == true`, `isOpaque == false`, `backgroundColor == .clear`, `hasShadow == false`, `level == .floating`, `canBecomeKey == false`, and `canBecomeMain == false`.

---

## Requirements *(mandatory)*

### Functional Requirements

| ID | Title | User Story | Priority | Status |
|----|-------|------------|----------|--------|
| FR-001 | Avatar Scale Domain Model, Presets & Clamping | As a user, I want an observable avatar sizing model/configuration supporting a base canvas size of `250×250` pt, a clamped scale range of `0.50...1.75` (`50%...175%`), named presets (`Small = 0.60`, `Medium = 0.80`, `Default = 1.00`, `Large = 1.25`, `Extra Large = 1.50`), and `±0.10` (`±10%`) step adjustments rounded to 2 decimal places so that avatar dimensions are deterministic. | High | Open |
| FR-002 | Proportional `MascotOverlayPanel` Frame Scaling & Bottom-Right Re-Anchoring | As a user, I want `MascotOverlayPanel` to compute its scaled size (`250 * scaleFactor` × `250 * scaleFactor`, bounded by `visibleFrame` margins) and bottom-right origin (`visibleFrame.maxX - panelSize.width - 20`, `visibleFrame.minY + 20`), updating both its window frame and hosted `NSHostingView` frame immediately whenever `scaleFactor` or screen parameters change. | High | Open |
| FR-003 | Proportional `MascotOverlayView` Canvas Scaling | As a user, I want `MascotOverlayView` to scale its `250×250` pt base mascot layout proportionally by `scaleFactor` within the scaled `MascotOverlayPanel` frame so that Bitz's ears, head, LED visor, body, tail, speech bubble, and telemetry pill scale uniformly without clipping. | High | Open |
| FR-004 | Menu Bar Manual Resize Controls (`BitzMenuBarContentView`) | As a user, I want `BitzMenuBarContentView` to display the current avatar scale percentage and pixel/point size alongside interactive controls for presets (`60%`, `80%`, `100%`, `125%`, `150%`), step adjustments (`-10%`, `+10%`), and `Reset (100%)` so that I can manually resize Bitz from the macOS Menu Bar. | High | Open |
| FR-005 | `UserDefaults` Scale Persistence & Sanitization | As a user, I want my selected `scaleFactor` persisted under the `"avatarScaleFactor"` key in `UserDefaults` and sanitized/clamped on load (`1.00` default when unset or `<= 0`, clamped to `0.50...1.75` otherwise) so that my preferred size survives app restarts. | Medium | Open |
| FR-006 | Living Documentation & Contract Synchronization | As a maintainer, I want `docs/ARCHITECTURE.md` and `docs/ACCEPTANCE_CRITERIA.md` updated to document configurable avatar scaling (`50%–175%` of `250×250` pt) and its test verification (`DIR-005`). | Medium | Open |

### Non-Functional Requirements

| ID | Title | Requirement | Category | Priority | Status |
|----|-------|-------------|----------|----------|--------|
| NFR-001 | Instantaneous Resize Latency | Manual scale changes from the Menu Bar must update `MascotOverlayPanel` and `MascotOverlayView` synchronously on `@MainActor` in `< 16ms` (1 frame at 60 FPS) with zero visual flicker. | Performance | High | Open |
| NFR-002 | CPU & Memory Budget Compliance at Max Scale | Even at maximum scale (`1.75x` / `437.5×437.5` pt), continuous 60 FPS rendering and background telemetry must remain within `< 2%` CPU on Apple Silicon and `< 70MB` RAM (`DIR-003`). | Performance | High | Open |
| NFR-003 | Automated Unit Test Coverage for Sizing & Geometry | Unit tests in `MascotOverlayPanelTests` (or dedicated sizing tests) must achieve `>= 80%` line coverage across all new scale clamping, preset, step, persistence, and bottom-right origin calculations. | Reliability | High | Open |
| NFR-004 | Swift 6 Strict Concurrency & Zero Warnings | `swift build` and `swift test` must compile with `0` warnings under Swift 6 strict concurrency (`@MainActor` / `Sendable`). | Maintainability | High | Open |

### Constraints

| ID | Title | Constraint | Category | Priority | Status |
|----|-------|------------|----------|----------|--------|
| C-001 | Unconditional Click-Through Windowing Invariant | `MascotOverlayPanel.ignoresMouseEvents` must remain `true` at all times across all sizes (`DIR-001`); resizing must never require making the desktop panel clickable or key-focusable. | Technical | High | Open |
| C-002 | Zero Desktop Wallpaper Modification | Resizing and repositioning must never invoke `NSWorkspace.shared.setDesktopImageURL` or modify the user's macOS wallpaper (`DIR-002`). | Technical | High | Open |
| C-003 | Default `250×250` pt Baseline Backward Compatibility | `MascotOverlayPanel.defaultPanelSize` (`250×250` pt at `scaleFactor = 1.00`) must remain the default baseline so existing callers and tests without explicit scale arguments continue to pass. | Technical | High | Open |

### Key Entities

- **`AvatarSizePreset`**: Enumeration of curated manual size presets (`small = 0.60`, `medium = 0.80`, `defaultSize = 1.00`, `large = 1.25`, `extraLarge = 1.50`) with human-readable labels and scale multipliers.
- **`AvatarScaleConfiguration` / Scale State**: `@MainActor` observable/persisted scale state managing `scaleFactor` (`0.50...1.75`, default `1.00`), step increment/decrement (`±0.10`), preset selection, clamping/sanitization, and `UserDefaults` synchronization (`"avatarScaleFactor"`).
- **`MascotOverlayPanel`**: Custom `NSPanel` updated to track `currentScaleFactor`, compute scaled panel dimensions (`250 * scaleFactor` × `250 * scaleFactor`), and anchor to the bottom-right of `NSScreen.main?.visibleFrame` on both manual resize and screen parameter notifications.
- **`MascotOverlayView`**: SwiftUI view updated to accept or observe `scaleFactor`, scaling its `250×250` base mascot canvas proportionally inside the scaled frame.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can manually select any of the 5 presets (`60%`, `80%`, `100%`, `125%`, `150%`) or step by `±10%` across `50%...175%` from the Menu Bar, and `MascotOverlayPanel.frame` immediately updates to `(250 * scale, 250 * scale)` anchored at `(visibleFrame.maxX - 250 * scale - 20, visibleFrame.minY + 20)`.
- **SC-002**: `MascotOverlayPanel` preserves `ignoresMouseEvents == true`, `isOpaque == false`, `backgroundColor == .clear`, `hasShadow == false`, and `canBecomeKey == false` before, during, and after every resize operation (verified by automated tests).
- **SC-003**: Selected `scaleFactor` persists in `UserDefaults` (`"avatarScaleFactor"`) and restores accurately on subsequent `BitzAppDelegate` initialization, while out-of-bounds or invalid persisted values are clamped to `0.50...1.75` or defaulted to `1.00`.
- **SC-004**: `swift build` and `swift test` pass with `0` failures and `0` compiler warnings under Swift 6 strict concurrency.
