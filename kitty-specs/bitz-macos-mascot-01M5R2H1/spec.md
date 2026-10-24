# Mission Specification: Bitz the Cyber Cat macOS Desktop Companion

**Mission Branch**: `feat/bitz-macos-mascot`  
**Mission Slug**: `bitz-macos-mascot-01M5R2H1`  
**Mission ID**: `01M5R2H1565BXFKD6TVZRRMH9V`  
**Created**: 2026-10-25  
**Status**: Approved  
**Input**: Implement "Bitz the Cyber Cat" (`bitz-mac`), a native macOS 14.0+ wellness and PC health desktop companion built in Swift 6, SwiftUI, AppKit, CoreGraphics, and `RiveRuntime`.

---

## Overview & Product Vision

**Bitz the Cyber Cat** is a tiny, round, matte-white and dark-gray robotic cat with glowing neon cyan inner ears, a floating detached tail, and a glossy black LED visor face that displays expressive pixel-art eyes (`^ ^`, `- -`, `> <`, `ZZZ`, `! !`).

Unlike static wallpaper utilities, Bitz lives directly on the user's macOS desktop inside a borderless, transparent, click-through `NSPanel` overlay (`MascotOverlayPanel`) positioned in the bottom-right corner above the macOS Dock. Bitz reflects the user's work-life balance and system thermal state in real time through a deterministic wellness point engine (`WellnessPointEngine`) and system telemetry service (`ActivityMonitorService`), driving a Metal-accelerated Rive animation state machine (`BitzStateMachine`) while consuming `< 2%` CPU on Apple Silicon and `< 70MB` RAM at 60 FPS.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Transparent Click-Through Desktop Companion Overlay (Priority: P1)

As a macOS user working across multiple applications and Spaces, I want Bitz to float unobtrusively in the bottom-right corner of my screen inside a transparent, click-through overlay panel that never steals focus, blocks mouse clicks, or modifies my desktop wallpaper, so that I can enjoy an ambient companion without any workflow interruption.

**Why this priority**: The transparent, non-activating, click-through windowing architecture (`MascotOverlayPanel`) is the foundational container and core user-experience guarantee of the product.

**Independent Test**: Launch the macOS application and verify that `MascotOverlayPanel` appears in the bottom-right visible screen frame (`250x250` pt), renders with a completely transparent background (`isOpaque == false`, `backgroundColor == .clear`, `hasShadow == false`), passes all mouse clicks through to underlying windows (`ignoresMouseEvents == true`), remains visible across Spaces (`collectionBehavior` includes `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`), and leaves the user's macOS desktop wallpaper untouched.

**Acceptance Scenarios**:

1. **Given** the user launches Bitz on macOS 14.0+, **When** `MascotOverlayPanel` initializes, **Then** it configures `styleMask = [.nonactivatingPanel, .borderless]`, `level = .floating`, `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`, `isMovableByWindowBackground = false`, `ignoresMouseEvents = true`, and `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`.
2. **Given** `MascotOverlayPanel` is positioned over an interactive UI element of another application (e.g., a browser button or code editor line in the bottom-right corner), **When** the user clicks directly on Bitz's `250x250` frame, **Then** the click passes straight through to the underlying application without activating Bitz or stealing focus (`canBecomeKey == false`, `canBecomeMain == false`).
3. **Given** the user has a custom macOS desktop wallpaper configured, **When** Bitz launches, runs, and quits, **Then** zero desktop wallpaper APIs are invoked and the user's wallpaper remains 100% unmodified.

---

### User Story 2 - Real-Time Wellness Point Scoring & Mascot State Transitions (Priority: P1)

As a developer or knowledge worker on macOS, I want Bitz's animation speed, posture, and LED visor color to dynamically respond to my work habits and rest breaks via a deterministic `0.0` to `100.0` Wellness Point score, so that I receive intuitive visual feedback on whether I am balanced, super-charged, overworked, or approaching burnout.

**Why this priority**: `WellnessPointEngine` is the core domain engine that translates user activity and rest into Bitz's behavioral states and Rive State Machine parameters.

**Independent Test**: Execute unit tests against `WellnessPointEngine` verifying initial state (`50.0` points, `.balanced`), work ticks (`+0.5` productive, `-1.5` distraction), offline recovery (`+5.0` pts/min when `>10` minutes), clamping (`0.0...100.0`), and exact threshold transitions across `.superCharged`, `.balanced`, `.overworked`, and `.burnout`.

**Acceptance Scenarios**:

1. **Given** `WellnessPointEngine` initializes at `50.0` points, **When** `evaluateState()` runs, **Then** `currentState` is `.balanced` (`40.0..<80.0` points) with Rive parameters `speedMultiplier = 1.0`, `visorColor = 0.0` (Cyan), `isGlitching = false`, and `isStandby = false`.
2. **Given** `WellnessPointEngine` is at `79.5` points, **When** `registerWorkTick(isProductiveApp: true)` is called (`+0.5` pts → `80.0` pts), **Then** `currentState` transitions to `.superCharged` (`80.0...100.0` points) with `speedMultiplier = 2.0`, `visorColor = 1.0` (Magenta), `isGlitching = false`, and `isStandby = false`.
3. **Given** `WellnessPointEngine` is at `40.0` points, **When** `registerWorkTick(isProductiveApp: false)` is called (`-1.5` pts → `38.5` pts), **Then** `currentState` transitions to `.overworked` (`15.0..<40.0` points) with `speedMultiplier = 0.4`, `visorColor = 2.0` (Amber), `isGlitching = false`, and `isStandby = false`.
4. **Given** `WellnessPointEngine` drops below `15.0` points (e.g., `14.5` pts), **When** `evaluateState()` runs, **Then** `currentState` transitions to `.burnout` (`<15.0` points) with `speedMultiplier = 0.0` and `isStandby = true` (standby loaf mode displaying `ZZZ` on the visor).
5. **Given** `WellnessPointEngine` is at `20.0` points, **When** `registerOfflineBreak(minutes: 12.0)` is called (`>10` minutes offline → `+60.0` pts → `80.0` pts), **Then** `points` increases by `5.0 * minutes` (clamped to `100.0`) and `currentState` updates to `.superCharged`.
6. **Given** `WellnessPointEngine` is at `20.0` points, **When** `registerOfflineBreak(minutes: 8.0)` is called (`<=10` minutes), **Then** `points` remains `20.0` because only breaks exceeding 10 minutes trigger offline recovery.

---

### User Story 3 - System Thermal Override & Activity Monitoring (Priority: P2)

As a macOS power user running intensive builds or workloads, I want Bitz to detect high CPU thermal states (`> 80°C` / serious or critical `ProcessInfo.ThermalState`) and immediately enter an `.overheating` alert state with red visor eyes (`! !`), glitch animation, and a `"SYSTEM HOT! > <"` warning bubble, so that I am alerted to hardware thermal stress regardless of my current wellness score.

**Why this priority**: Hardware health monitoring (`ActivityMonitorService`) and the thermal override complete the dual "User Wellness & PC Health" value proposition.

**Independent Test**: Trigger `WellnessPointEngine.triggerThermalWarning(isOverheating: true)` across all wellness point levels (`0.0` to `100.0`) and verify that `.overheating` overrides any point-based state, sets `isGlitching = true` and `visorColor = 3.0` (Red), displays the warning speech bubble in `MascotOverlayView`, and restores the underlying point-based state when `triggerThermalWarning(isOverheating: false)` is called.

**Acceptance Scenarios**:

1. **Given** `WellnessPointEngine` is at `90.0` points (`.superCharged`), **When** `triggerThermalWarning(isOverheating: true)` is invoked due to CPU temperature `> 80°C` or high thermal state, **Then** `currentState` immediately becomes `.overheating`, `isGlitching` becomes `true`, `visorColor` becomes `3.0` (Red), and `MascotOverlayView` displays `"SYSTEM HOT! > <"`.
2. **Given** `WellnessPointEngine` is in `.overheating` at `90.0` points, **When** `triggerThermalWarning(isOverheating: false)` is invoked once thermals normalize, **Then** `isGlitching` resets to `false` and `evaluateState()` restores `currentState` to `.superCharged` (`visorColor = 1.0`, `speedMultiplier = 2.0`).
3. **Given** `ActivityMonitorService` is running its background polling timer (`60s` interval), **When** it inspects the frontmost application via `NSWorkspace.shared.frontmostApplication`, **Then** it classifies known IDE/productivity bundle identifiers (e.g., Xcode, VS Code, Terminal) as productive (`isProductiveApp: true`), distracting/social apps as non-productive (`isProductiveApp: false`), tracks system idle/sleep duration via CoreGraphics (`CGEventSource.secondsSinceLastEventType`) / workspace notifications, and forwards thermal state changes from `ProcessInfo.processInfo.thermalState` to `WellnessPointEngine`.

---

### User Story 4 - Rive State Machine Bridge & Living Architecture Documentation (Priority: P2)

As a maintainer and animator integrating `bitz_mascot.riv`, I want `MascotOverlayView` to cleanly bridge `WellnessPointEngine` state into the `BitzStateMachine` Rive inputs (with a graceful procedural SwiftUI/Canvas fallback when the binary `.riv` asset is not yet bundled) alongside synchronized living documentation (`docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, `docs/ACCEPTANCE_CRITERIA.md`), so that the application builds, runs, and is verifiable out of the box.

**Why this priority**: Ensures the Swift package/app compiles cleanly with zero warnings, renders Bitz visually even before external `.riv` binary assets are dropped in, and maintains complete specification-to-code documentation parity.

**Independent Test**: Build and test the Swift package (`swift build` and `swift test`), verify `MascotOverlayView` synchronizes `speedMultiplier`, `visorColor`, `isStandby`, `isGlitching`, and `triggerPet` inputs on every `currentState` change, and verify `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, and `docs/ACCEPTANCE_CRITERIA.md` exist and match the implemented contracts.

**Acceptance Scenarios**:

1. **Given** `WellnessPointEngine.currentState` changes to any `BitzState` case, **When** `MascotOverlayView.syncRiveState(for:)` executes, **Then** all `BitzStateMachine` inputs (`speedMultiplier`, `visorColor`, `isStandby`, `isGlitching`) are updated deterministically to match the state specification.
2. **Given** the repository is built on macOS 14.0+, **When** `swift build` and `swift test` execute, **Then** compilation succeeds with zero warnings and unit tests achieve `>= 80%` line coverage across `WellnessPointEngine` and `ActivityMonitorService`.

---

### Edge Cases

- **Point Clamping at Boundaries**: Calling `registerWorkTick(isProductiveApp: true)` at `100.0` points must clamp `points` at `100.0` (never `100.5`). Calling `registerWorkTick(isProductiveApp: false)` at `0.5` points must clamp `points` at `0.0` (never `-1.0`).
- **Exact Threshold Boundaries**:
  - `80.0` points is `.superCharged` (`80.0...100.0`).
  - `79.9` points and `40.0` points are `.balanced` (`40.0..<80.0`).
  - `39.9` points and `15.0` points are `.overworked` (`15.0..<40.0`).
  - `14.9` points and `0.0` points are `.burnout` (`<15.0`).
- **Thermal Override Precedence During Work Ticks**: If `currentState == .overheating` and `registerWorkTick` or `registerOfflineBreak` is called while overheating remains active, `points` must still update and clamp accurately in the background, while `currentState` remains `.overheating` until `triggerThermalWarning(isOverheating: false)` is called.
- **Short Breaks (`<= 10.0` minutes)**: `registerOfflineBreak(minutes: 10.0)` must not add points; only `minutes > 10.0` triggers `+5.0 * minutes` recovery.
- **Multi-Monitor / Dock Repositioning**: `MascotOverlayPanel` positions itself relative to `NSScreen.main?.visibleFrame` (`maxX - 270`, `minY + 20`) so it never overlaps the macOS Dock or menu bar, and safely handles `NSScreen.main == nil` without crashing.
- **Missing Binary `.riv` Asset**: If `bitz_mascot.riv` is absent from bundle resources at runtime, the Rive bridge must not crash on force-unwrap; it must safely guard resource loading and render a lightweight vector fallback view while still tracking all state machine inputs for inspection and testing.

---

## Requirements *(mandatory)*

### Functional Requirements

| ID | Title | User Story | Priority | Status |
|----|-------|------------|----------|--------|
| FR-001 | Borderless Click-Through `MascotOverlayPanel` | As a macOS user, I want `MascotOverlayPanel` (`NSPanel` subclass) to configure `[.nonactivatingPanel, .borderless]`, `level = .floating`, `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`, `isMovableByWindowBackground = false`, `ignoresMouseEvents = true`, and `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` so that Bitz floats above windows in the bottom-right visible frame (`250x250` pt) without intercepting mouse events or stealing focus. | High | Open |
| FR-002 | Deterministic `WellnessPointEngine` Scoring & Clamping | As a user, I want `WellnessPointEngine` to start at `50.0` points (`0.0...100.0` clamped), apply `+0.5` points per productive work tick, `-1.5` points per non-productive/distraction work tick, and `+5.0` points per minute for offline breaks strictly greater than `10.0` minutes so that my work-life balance score is tracked accurately. | High | Open |
| FR-003 | Five-State `BitzState` Evaluation & Thermal Override | As a user, I want `WellnessPointEngine` to evaluate `.superCharged` (`80.0...100.0`), `.balanced` (`40.0..<80.0`), `.overworked` (`15.0..<40.0`), and `.burnout` (`<15.0`), and allow `triggerThermalWarning(isOverheating:)` to override any point state into `.overheating` (`isGlitching = true`, `visorColor = 3.0`) and restore the point state when thermals normalize. | High | Open |
| FR-004 | `BitzStateMachine` Rive Parameter Contract | As an animator and developer, I want `WellnessPointEngine` and `MascotOverlayView` to expose and synchronize the exact Rive State Machine (`BitzStateMachine`) inputs (`speedMultiplier`: Float `0.0...2.5`, `visorColor`: Float `0.0`=Cyan, `1.0`=Magenta, `2.0`=Amber, `3.0`=Red, `isStandby`: Bool, `isGlitching`: Bool, `triggerPet`: Trigger) whenever state transitions occur. | High | Open |
| FR-005 | `ActivityMonitorService` Workspace, Idle & Thermal Telemetry | As a user, I want `ActivityMonitorService` to poll frontmost application bundle identifiers via `NSWorkspace`, measure system idle duration via CoreGraphics (`CGEventSource.secondsSinceLastEventType`), observe macOS sleep/wake/screen-lock notifications, and monitor thermal state (`ProcessInfo.processInfo.thermalState`) to drive `WellnessPointEngine` automatically. | High | Open |
| FR-006 | `MascotOverlayView` Presentation & Thermal Warning Bubble | As a user, I want `MascotOverlayView` to render Bitz within a `250x250` transparent frame and animate a `"SYSTEM HOT! > <"` red capsule warning speech bubble whenever `engine.currentState == .overheating`. | Medium | Open |
| FR-007 | Living Architecture, State Machine & Acceptance Documentation | As a maintainer, I want `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, and `docs/ACCEPTANCE_CRITERIA.md` authored and kept synchronized with the codebase so that windowing invariants, Rive input bindings, and acceptance gates remain inspectable. | Medium | Open |

### Non-Functional Requirements

| ID | Title | Requirement | Category | Priority | Status |
|----|-------|-------------|----------|----------|--------|
| NFR-001 | Idle & Active CPU Budget | Continuous background telemetry and 60 FPS mascot rendering must consume `< 2%` CPU on Apple Silicon Macs. | Performance | High | Open |
| NFR-002 | Memory Footprint Cap | Resident memory footprint (`phys_footprint`) of the running application must remain `< 70MB` RAM at 60 FPS. | Performance | High | Open |
| NFR-003 | Core Service Unit Test Coverage | Automated unit tests using Swift Testing / `XCTest` must achieve `>= 80%` line coverage across `WellnessPointEngine` and `ActivityMonitorService`. | Reliability | High | Open |
| NFR-004 | Zero Compiler Warnings under Swift 6 Strict Concurrency | `swift build` and `swift test` must complete with zero compiler warnings and strict Swift 6 concurrency isolation (`@MainActor` / `Sendable`). | Maintainability | High | Open |

### Constraints

| ID | Title | Constraint | Category | Priority | Status |
|----|-------|------------|----------|----------|--------|
| C-001 | Zero Desktop Wallpaper Modification | The application must never invoke `NSWorkspace.shared.setDesktopImageURL` or modify the user's macOS desktop wallpaper in any way (`PROJECT_002`). | Technical | High | Open |
| C-002 | Unconditional Click-Through Windowing | `MascotOverlayPanel.ignoresMouseEvents` must remain `true` so desktop clicks are never blocked (`PROJECT_002`). | Technical | High | Open |
| C-003 | Platform & Architecture Target | Must target macOS 14.0+ (Sonoma or newer) as a Universal architecture package/app (Apple Silicon `arm64` & Intel `x86_64`) using Swift 6. | Technical | High | Open |
| C-004 | Mission Scope Boundary | Scope is strictly limited to the native macOS desktop companion (`MascotOverlayPanel`, `WellnessPointEngine`, `ActivityMonitorService`, `MascotOverlayView`, app entry point, tests, and `docs/`) with no cloud backend, telemetry upload, or kernel extensions (`PROJECT_001`). | Business | High | Open |

### Key Entities

- **`BitzState`**: Enumeration representing Bitz's five behavioral modes: `.superCharged`, `.balanced`, `.overworked`, `.burnout`, and `.overheating`.
- **`WellnessPointEngine`**: `@MainActor` observable state machine managing `points` (`0.0...100.0`), `currentState` (`BitzState`), and Rive input properties (`speedMultiplier`, `visorColor`, `isStandby`, `isGlitching`, `petTriggerCount`).
- **`ActivityMonitorService`**: `@MainActor` telemetry coordinator that classifies frontmost macOS applications (productive vs. distraction), tracks user idle/offline break durations, monitors `ProcessInfo.ThermalState`, and feeds ticks into `WellnessPointEngine`.
- **`MascotOverlayPanel`**: Custom `NSPanel` subclass enforcing borderless, transparent, floating, stationary, non-activating, click-through desktop overlay windowing.
- **`MascotOverlayView`**: SwiftUI view hosting the Rive `BitzStateMachine` view model (and safe vector fallback) plus the `.overheating` warning bubble inside `MascotOverlayPanel`.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `MascotOverlayPanel` initializes with `ignoresMouseEvents == true`, `isOpaque == false`, `backgroundColor == .clear`, `hasShadow == false`, `level == .floating`, and `canBecomeKey == false` (verified by automated tests).
- **SC-002**: 100% of `WellnessPointEngine` threshold boundaries (`80.0`, `40.0`, `15.0`, `0.0`), point deltas (`+0.5`, `-1.5`, `+5.0/min` for `>10m`), clamping (`0.0...100.0`), and `.overheating` override/recovery transitions pass deterministic unit tests.
- **SC-003**: Automated test suite (`swift test`) passes with `0` failures, `0` compiler warnings, and `>= 80%` code coverage on `WellnessPointEngine` and `ActivityMonitorService`.
- **SC-004**: Living documentation files (`docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, `docs/ACCEPTANCE_CRITERIA.md`) are present, complete, and match the implemented Swift interfaces and Rive state machine contract.
