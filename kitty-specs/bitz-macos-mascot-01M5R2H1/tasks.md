# Work Packages: Bitz macOS Desktop Companion

**Mission**: `bitz-macos-mascot-01M5R2H1` (`01M5R2H1565BXFKD6TVZRRMH9V`)
**Inputs**: Design documents from `/kitty-specs/bitz-macos-mascot-01M5R2H1/`
**Prerequisites**: `plan.md` (required), `spec.md` (user stories & requirements), `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: Comprehensive XCTest suites (`WellnessPointEngineTests`, `ActivityMonitorServiceTests`, `MascotOverlayPanelTests`) are explicitly required by `NFR-004` and Charter `DIR-004` (`>= 80%` unit test coverage on `WellnessPointEngine` and `ActivityMonitorService`).

**Organization**: Fine-grained subtasks (`T001`–`T019`) roll up into 4 cohesive Work Packages (`WP01`–`WP04`) aligned 1-to-1 with Implementation Chunks `IC-01`–`IC-04` from `plan.md`. Each work package is independently deliverable, testable, and owns a strictly disjoint file set (`owned_files`).

---

## Work Package WP01: Foundation, Rive Adapter Seam & WellnessPointEngine (Priority: P0)

**Goal**: Scaffold the Swift 6 Package (`Package.swift`), define the `BitzState` domain enumeration and `BitzRiveControllable` Rive state machine adapter seam (`BitzStateMachine`), and implement the `@MainActor ObservableObject` `WellnessPointEngine` with `>= 80%` unit test coverage.
**Independent Test**: Run `swift test --filter WellnessPointEngineTests` to verify initial `50.0` score, `+0.5` productive tick, `-1.5` unproductive tick, `0.0...100.0` clamping, offline break restoration (`+5.0` pts/min when `minutes > 10.0`, `0` pts when `minutes <= 10.0`), all 5 `BitzState` thresholds, Rive input mapping (`speedMultiplier`, `visorColor`, `isStandby`, `isGlitching`, `triggerPet`), and thermal warning override/recovery.
**Prompt**: `/tasks/WP01-foundation-and-wellness-engine.md`
**Requirement Refs**: FR-002, FR-003, FR-004

### Included Subtasks
T001 Scaffold Swift 6 `Package.swift` (macOS 14.0+ platform target, `BitzCore` library target, `BitzApp` executable target, `BitzTests` test target, strict concurrency flags)
T002 Define `BitzState` enum, `BitzRiveCommand` value log, `BitzRiveControllable` protocol, and `SpyRiveController` / `ProductionRiveController` adapter seam in `src/Services/WellnessPointEngine.swift`
T003 Implement `@MainActor final class WellnessPointEngine: ObservableObject` with `evaluateWorkTick(isProductiveApp:)`, `applyOfflineBreak(minutes:)`, `evaluateState()`, and `syncWithRive()` in `src/Services/WellnessPointEngine.swift`
T004 Implement `triggerThermalWarning(isOverheating:)` override/recovery and `triggerPetInteraction()` in `src/Services/WellnessPointEngine.swift`
T005 Write comprehensive unit tests in `Tests/BitzTests/WellnessPointEngineTests.swift` covering all boundary thresholds, clamping, offline breaks, thermal override/recovery, and Rive input assertions (`>= 80%` coverage)

### Implementation Notes
- Keep `WellnessPointEngine` and `BitzRiveControllable` in `src/Services/WellnessPointEngine.swift` as part of the `BitzCore` target so XCTest can import and test them deterministically without requiring a live GPU window or `.riv` binary asset.
- Ensure exact Rive `BitzStateMachine` input identifiers: `speedMultiplier` (`Float`), `visorColor` (`Float`: `0.0`=Cyan, `1.0`=Magenta, `2.0`=Amber, `3.0`=Red), `isStandby` (`Bool`), `isGlitching` (`Bool`), and `triggerPet` (Trigger).
- Persist non-overheating point state via `evaluateState()` so `triggerThermalWarning(isOverheating: false)` immediately restores the exact point-derived state and Rive inputs.

### Parallel Opportunities
- T002 and T003 can be developed together once T001 (`Package.swift`) compiles.

### Dependencies
- None (starting work package).

### Risks & Mitigations
- **Swift 6 strict concurrency isolation violations**: Mark `WellnessPointEngine` as `@MainActor` and `BitzRiveControllable` as `@MainActor` (or `Sendable`) so all UI and Rive state mutations are compile-time verified on the main actor.
- **Boundary condition off-by-one**: Explicitly test `79.9`, `80.0`, `40.0`, `39.9`, `15.0`, `14.9`, and `minutes == 10.0` vs `10.1`.

---

## Work Package WP02: ActivityMonitorService & Privacy-Safe System Telemetry (Priority: P0)

**Goal**: Implement `@MainActor final class ActivityMonitorService` with Injectable clock/workspace/thermal/idle providers (`ActivityTelemetryProviding`) for active app bundle ID classification, `CGEventSource` idle time detection, offline break calculation (`> 10.0` minutes), and thermal state monitoring (`ProcessInfo.ThermalState` + optional temperature threshold `> 80.0°C`), achieving `>= 80%` unit test coverage.
**Independent Test**: Run `swift test --filter ActivityMonitorServiceTests` to verify productive vs. unproductive bundle ID classification, idle break transition (`isOnBreak` after `60.0`s idle and `applyOfflineBreak(minutes:)` upon active return), and thermal warning propagation to `WellnessPointEngine`.
**Prompt**: `/tasks/WP02-activity-monitor-telemetry.md`
**Requirement Refs**: FR-005

### Included Subtasks
T006 Define `ActivityTelemetryProviding` protocol (`frontmostBundleIdentifier()`, `secondsSinceLastInput()`, `thermalState()`, `cpuTemperatureCelsius()`, `now()`) and `SystemActivityTelemetryProvider` in `src/Services/ActivityMonitorService.swift`
T007 Implement productive bundle ID whitelist (`com.apple.dt.Xcode`, `com.microsoft.VSCode`, `com.apple.Terminal`, `com.googlecode.iterm2`, `com.todesktop.230313mzl4w4u92`, `dev.warp.Warp-Stable`, `com.jetbrains.intellij`) and `isProductiveBundleID(_:)` in `src/Services/ActivityMonitorService.swift`
T008 Implement `@MainActor final class ActivityMonitorService` polling tick (`performSampleTick()`), idle-to-active break restoration (`applyOfflineBreak(minutes:)`), and work tick forwarding (`evaluateWorkTick(isProductiveApp:)`) in `src/Services/ActivityMonitorService.swift`
T009 Implement thermal state evaluation (`thermalState == .critical || thermalState == .serious || cpuTemperatureCelsius > 80.0`) forwarding `triggerThermalWarning(isOverheating:)` in `src/Services/ActivityMonitorService.swift`
T010 Write unit tests in `Tests/BitzTests/ActivityMonitorServiceTests.swift` using `MockTelemetryProvider` for app classification, idle break recovery (`<= 10.0` min vs `> 10.0` min), and thermal spike/recovery (`>= 80%` coverage)

### Implementation Notes
- Zero Accessibility / keylogging APIs (`AXIsProcessTrusted`, `CGEvent.tapCreate`) are permitted (`C-003`, `DIR-003`). Only read `NSWorkspace.shared.frontmostApplication?.bundleIdentifier` and `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)`.
- Expose `performSampleTick()` as an internal/public method on `ActivityMonitorService` so unit tests can drive telemetry cycles deterministically without sleeping on wall-clock `Timer` intervals.

### Parallel Opportunities
- T006/T007 and T009 can be implemented modularly before wiring the full `performSampleTick()` in T008.

### Dependencies
- Depends on WP01 (`WellnessPointEngine` and `BitzCore` target in `Package.swift`).

### Risks & Mitigations
- **Flaky timer-based tests**: Inject `ActivityTelemetryProviding` with a deterministic clock (`now()`) and test via direct `performSampleTick()` calls rather than `Task.sleep`.

---

## Work Package WP03: MascotOverlayPanel, MascotOverlayView & BitzApp Lifecycle (Priority: P1)

**Goal**: Implement the click-through, transparent, non-activating `MascotOverlayPanel` (`NSPanel`), the SwiftUI `MascotOverlayView` with speech bubble and Rive state visualization, the `BitzApp` menu bar extra & application delegate lifecycle, and `MascotOverlayPanelTests` verifying all window invariants.
**Independent Test**: Run `swift test --filter MascotOverlayPanelTests` to verify all `NSPanel` window invariants (`isOpaque == false`, `backgroundColor == .clear`, `hasShadow == false`, `level == .floating`, `ignoresMouseEvents == true`, `canBecomeKey == false`, `canBecomeMain == false`, `collectionBehavior`, bottom-right `250x250` anchor calculation).
**Prompt**: `/tasks/WP03-overlay-window-and-rive-view.md`
**Requirement Refs**: FR-001, FR-004, FR-006

### Included Subtasks
T011 Implement `@MainActor final class MascotOverlayPanel: NSPanel` in `src/App/Window/MascotOverlayPanel.swift` with borderless/nonactivating style mask, floating level, transparent clear background, click-through `ignoresMouseEvents = true`, multi-space collectionBehavior, and `canBecomeKey`/`canBecomeMain` returning `false`
T012 Implement bottom-right screen frame calculation (`calculateOrigin(for visibleFrame: NSRect, panelSize: NSSize) -> NSPoint` with `maxX - 270`, `minY + 20`) and `NSApplication.didChangeScreenParametersNotification` observer in `src/App/Window/MascotOverlayPanel.swift`
T013 Implement `MascotOverlayView` in `src/Views/MascotOverlayView.swift` rendering the `250x250` cyberpunk mascot canvas, state-driven visor glow (`Cyan`, `Magenta`, `Amber`, `Red`), `"SYSTEM HOT! > <"` overheating speech bubble banner, and standby `"ZZZ"` indicator
T014 Implement `BitzApp` (`@main`) and `BitzAppDelegate` in `src/App/BitzApp.swift` wiring `WellnessPointEngine`, `ActivityMonitorService`, `MascotOverlayPanel`, and a lightweight `MenuBarExtra` status item with `"Pet Bitz"` trigger and wellness readout
T015 Write unit tests in `Tests/BitzTests/MascotOverlayPanelTests.swift` verifying all `MascotOverlayPanel` invariants and bottom-right screen geometry calculations

### Implementation Notes
- `MascotOverlayPanel` must be usable by unit tests (`BitzCore` or imported module) so `MascotOverlayPanelTests` can instantiate `MascotOverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 250, height: 250))` on `@MainActor` and assert every window property in `contracts/overlay-window-contract.md`.
- Strictly forbid any desktop wallpaper API calls (`NSWorkspace.shared.setDesktopImageURL`) per `C-001` / `DIR-001`.

### Parallel Opportunities
- T011/T012 (`MascotOverlayPanel`) and T013 (`MascotOverlayView`) can be built in parallel before wiring `BitzApp` in T014.

### Dependencies
- Depends on WP01 (`WellnessPointEngine`, `BitzState`, `BitzRiveControllable`) and WP02 (`ActivityMonitorService`).

### Risks & Mitigations
- **Headless CI screen availability**: Implement `MascotOverlayPanel.calculateOrigin(for:panelSize:)` as a pure static/instance helper taking an `NSRect` so geometry tests pass even when `NSScreen.main` is nil or varies across developer displays.

---

## Work Package WP04: Living Documentation & Acceptance Verification (Priority: P1)

**Goal**: Author and synchronize the living project documentation (`docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, `docs/ACCEPTANCE_CRITERIA.md`) required by `FR-007` and `DIR-005`, and run full build + test + coverage verification across the entire workspace.
**Independent Test**: Verify `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, and `docs/ACCEPTANCE_CRITERIA.md` exist, accurately reflect all implemented types/methods/thresholds, and `swift test --enable-code-coverage` passes with zero warnings and `>= 80%` coverage on `WellnessPointEngine` and `ActivityMonitorService`.
**Prompt**: `/tasks/WP04-living-docs-and-verification.md`
**Requirement Refs**: FR-007

### Included Subtasks
T016 Author `docs/ARCHITECTURE.md` documenting the 3-layer architecture (`MascotOverlayPanel`, `MascotOverlayView`, `WellnessPointEngine`, `ActivityMonitorService`), Swift 6 `@MainActor` concurrency model, and privacy/sandbox guarantees
T017 Author `docs/STATE_MACHINE.md` documenting the `BitzStateMachine` Rive inputs (`speedMultiplier`, `visorColor`, `isStandby`, `isGlitching`, `triggerPet`), state transition table, wellness scoring rules, and thermal override restoration semantics
T018 Author `docs/ACCEPTANCE_CRITERIA.md` mapping `FR-001`–`FR-007`, `NFR-001`–`NFR-004`, `C-001`–`C-004`, and `SC-001`–`SC-004` to concrete test cases and verification commands
T019 Execute end-to-end verification (`swift build`, `swift test --enable-code-coverage`, zero wallpaper/accessibility API audit) and confirm all acceptance criteria in `docs/ACCEPTANCE_CRITERIA.md` pass

### Implementation Notes
- Ensure all code symbols, file paths, Rive input names, and point formulas in `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, and `docs/ACCEPTANCE_CRITERIA.md` match the exact implementation in `src/` and `Tests/BitzTests/`.

### Parallel Opportunities
- T016, T017, and T018 touch separate documentation files and can be drafted in parallel before final verification in T019.

### Dependencies
- Depends on WP01, WP02, and WP03.

### Risks & Mitigations
- **Documentation drift**: Cross-check all method signatures and threshold constants against `src/Services/WellnessPointEngine.swift`, `src/Services/ActivityMonitorService.swift`, and `src/App/Window/MascotOverlayPanel.swift` during T019.

---

## Dependency & Execution Summary

- **Execution Sequence**:
  1. `WP01` (Foundation, Rive Seam & `WellnessPointEngine`) — Base foundation (`dependencies: []`)
  2. `WP02` (`ActivityMonitorService` & Telemetry) — Depends on `WP01` (`dependencies: ["WP01"]`)
  3. `WP03` (`MascotOverlayPanel`, `MascotOverlayView` & `BitzApp`) — Depends on `WP01`, `WP02` (`dependencies: ["WP01", "WP02"]`)
  4. `WP04` (Living Documentation & End-to-End Verification) — Depends on `WP01`, `WP02`, `WP03` (`dependencies: ["WP01", "WP02", "WP03"]`)
- **MVP Scope**: `WP01` + `WP02` + `WP03` + `WP04` constitute the complete, verified Bitz macOS Desktop Companion release.

---

## Requirements Coverage Summary

| Requirement ID | Summary | Covered By Work Package(s) |
| :--- | :--- | :--- |
| `FR-001` | Transparent Click-Through Desktop Overlay (`MascotOverlayPanel`) | `WP03` |
| `FR-002` | Wellness Point Engine & Scoring Mechanics (`WellnessPointEngine`) | `WP01` |
| `FR-003` | Reactive Rive State Machine Bridge (`BitzStateMachine` / `BitzRiveControllable`) | `WP01` |
| `FR-004` | Thermal Overheating Override & Speech Bubble Warning (`"SYSTEM HOT! > <"`) | `WP01`, `WP03` |
| `FR-005` | Privacy-Safe Foreground App & Idle Activity Monitoring (`ActivityMonitorService`) | `WP02` |
| `FR-006` | Pet Interaction Trigger (`triggerPet` via Menu Bar Extra) | `WP01`, `WP03` |
| `FR-007` | Living Project Documentation (`docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, `docs/ACCEPTANCE_CRITERIA.md`) | `WP04` |
| `NFR-001` | `< 2%` average CPU usage on Apple Silicon | `WP02`, `WP03`, `WP04` |
| `NFR-002` | `< 70MB` resident memory footprint at 60 FPS | `WP03`, `WP04` |
| `NFR-003` | 100% mouse click-through latency (`0ms` interception) | `WP03` |
| `NFR-004` | `>= 80%` unit test coverage on `WellnessPointEngine` & `ActivityMonitorService` | `WP01`, `WP02`, `WP04` |
| `C-001` | Zero Desktop Wallpaper Modification | `WP03`, `WP04` |
| `C-002` | Native Platform & Concurrency Baseline (macOS 14.0+, Swift 6) | `WP01`, `WP02`, `WP03` |
| `C-003` | App Sandbox & Privacy Compliance | `WP02`, `WP04` |
| `C-004` | Exact Rive Input Identifiers (`BitzStateMachine`) | `WP01`, `WP04` |

---

## Subtask Index (Reference)

| Subtask ID | Summary | Work Package | Priority | Parallel? |
| :--- | :--- | :--- | :--- | :--- |
| `T001` | Scaffold Swift 6 `Package.swift` | `WP01` | P0 | No |
| `T002` | Define `BitzState`, `BitzRiveCommand`, `BitzRiveControllable`, and Rive controllers | `WP01` | P0 | Yes |
| `T003` | Implement `WellnessPointEngine` work ticks, offline breaks, and `syncWithRive()` | `WP01` | P0 | Yes |
| `T004` | Implement `triggerThermalWarning(isOverheating:)` and `triggerPetInteraction()` | `WP01` | P0 | No |
| `T005` | Write `WellnessPointEngineTests` (`>= 80%` coverage) | `WP01` | P0 | No |
| `T006` | Define `ActivityTelemetryProviding` and `SystemActivityTelemetryProvider` | `WP02` | P0 | Yes |
| `T007` | Implement productive bundle ID whitelist and `isProductiveBundleID(_:)` | `WP02` | P0 | Yes |
| `T008` | Implement `ActivityMonitorService` polling and idle-to-active break restoration | `WP02` | P0 | No |
| `T009` | Implement thermal state evaluation in `ActivityMonitorService` | `WP02` | P0 | Yes |
| `T010` | Write `ActivityMonitorServiceTests` (`>= 80%` coverage) | `WP02` | P0 | No |
| `T011` | Implement `MascotOverlayPanel` (`NSPanel` subclass with click-through & transparency) | `WP03` | P1 | Yes |
| `T012` | Implement bottom-right screen frame calculation and screen change observer | `WP03` | P1 | Yes |
| `T013` | Implement `MascotOverlayView` (`250x250` canvas, visor glow, thermal speech bubble) | `WP03` | P1 | Yes |
| `T014` | Implement `BitzApp` (`@main`), `BitzAppDelegate`, and `MenuBarExtra` | `WP03` | P1 | No |
| `T015` | Write `MascotOverlayPanelTests` verifying all window invariants and geometry | `WP03` | P1 | No |
| `T016` | Author `docs/ARCHITECTURE.md` | `WP04` | P1 | Yes |
| `T017` | Author `docs/STATE_MACHINE.md` | `WP04` | P1 | Yes |
| `T018` | Author `docs/ACCEPTANCE_CRITERIA.md` | `WP04` | P1 | Yes |
| `T019` | Execute end-to-end build, test, coverage, and compliance verification | `WP04` | P1 | No |
