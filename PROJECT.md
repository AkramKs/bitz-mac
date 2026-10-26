# Project: bitz-mac Quality Improvement & PTS Edge-Case Hardening

## Architecture
- **Package**: `Bitz` macOS desktop mascot app (Swift tools 6.0, macOS 14+).
- **Modules / Targets**:
  - `BitzCore`: Core application logic, services, views, and state machine (`src/`).
  - `Bitz`: Executable entry point (`src/Executable/main.swift`).
  - `BitzTests`: Test suite covering services, panel geometry, and engine logic (`Tests/BitzTests`).
- **Data Flow**:
  - Telemetry (`ActivityMonitorService`) samples system activity, thermal state, idle time, and browser tabs every 5 seconds.
  - Feed events (`evaluateWorkTick`, `setChargingState`, `applyOfflineBreak`, `triggerThermalWarning`) into `WellnessPointEngine`.
  - `WellnessPointEngine` manages points (0–100), work streak, and transitions between states: `.superCharged`, `.balanced`, `.dopamineSad`, `.overworked`, `.burnout`, `.overheating`, `.charging`.
  - State synchronizes to `BitzRiveControllable` (drives the Rive state machine inputs and SwiftUI vector avatar in `MascotOverlayView`).
  - State persists asynchronously to `UserDefaults`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | CI Workflow Action Tag Restoration | Restore `.github/workflows/ci.yml` and `pr-ticket-check.yml` to official tags (`checkout@v4`, `github-script@v7`) | M1 | Survey |
| F2 | Mascot Overlay Panel Memory Leak Fix | Capture and clean up `NSApplication.didChangeScreenParametersNotification` observer token on deinit | M1 | Survey |
| F3 | PTS Numeric Sanitization & Finite Checks | Guard `currentPoints`, deltas, and `continuousWorkMinutes` against `NaN`/`Infinity` | M2 | Survey |
| F4 | PTS Clock Skew & Negative Delta Clamping | Prevent negative durations from backwards time adjustments in `init` and `evaluateWorkTick` | M2 | Survey |
| F5 | PTS Epoch Zero & Future Timestamp Rejection | Validate persistence timestamps (reject epoch 0.0 and future timestamps) | M2 | Survey |
| F6 | Rive State Machine Contract Alignment | Complete `.overheating` Rive inputs (`speedMultiplier = 2.5`, `isStandby = false`) and `.charging` (`speedMultiplier = 0.6`) | M2 | Survey |
| F7 | Break Double-Counting Prevention | Eliminate double awarding of PTS between 5s idle charging ticks and cumulative offline breaks | M2 | Survey |
| F8 | Sleep Notification Timestamp Preservation | Preserve earliest sleep timestamp across `screensDidSleepNotification` and `willSleepNotification` | M2 | Survey |
| F9 | Browser Tab Telemetry I/O Optimization | Cache browser tab lookup per sample tick, cutting duplicate Firefox disk reads and Safari AppleScripts | M2 | Survey |
| F10 | Pet Interaction Burst Debounce & Task Management | Manage async pet reaction task with cancellation so rapid taps extend rather than cut off reaction | M2 | Survey |
| F11 | Automated PTS Edge Case Test Suite | 8+ automated tests verifying each edge case, confirming failure on original and pass on fixed | M3 | Survey |
| F12 | Test Suite Isolation & Stability | Isolate tests with dedicated `UserDefaults` suites to avoid test flakiness or cross-test leakage | M3 | Survey |
| F13 | State Machine Documentation Update | Comprehensive specification of states, invariants, and 8+ edge case scenarios in `docs/STATE_MACHINE.md` | M4 | Survey |
| F14 | Architecture & Acceptance Criteria Sync | Update `docs/ARCHITECTURE.md` and `docs/ACCEPTANCE_CRITERIA.md` with true measured metrics and contracts | M4 | Survey |
| F15 | Repository Review Report | Create `REPORT.md` documenting fixed and deferred items, file references, edge cases, and verification results | M4 | Survey |
| F16 | Regression & Quality Acceptance Verification | Independent verification of clean build (`-warnings-as-errors`), test pass, and zero regressions | M5 | Survey |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Quality, CI & Memory Fixes | CI action tags, `MascotOverlayPanel` observer cleanup | none | DONE |
| M2 | PTS Logic Hardening & Telemetry Optimization | `WellnessPointEngine` & `ActivityMonitorService` edge-case hardening | none | DONE |
| M3 | Automated PTS Edge-Case Tests | 8+ new automated tests covering all edge case scenarios | M2 | DONE |
| M4 | Documentation Sync & Repository Report | `docs/STATE_MACHINE.md`, `ARCHITECTURE.md`, `ACCEPTANCE_CRITERIA.md`, `REPORT.md` | M1, M2, M3 | DONE |
| M5 | Final Independent Verification & Review | Full clean build with warnings-as-errors, full test suite execution, acceptance checklist sign-off | M1, M2, M3, M4 | DONE |

## Interface Contracts
### `WellnessPointEngine` ↔ Callers (`ActivityMonitorService`, `MascotOverlayPanel`, Tests)
- `init(initialPoints: Double, initialContinuousWorkMinutes: Double, riveController: BitzRiveControllable?, userDefaults: UserDefaults)`:
  - Sanitizes `initialPoints` to finite range `[0.0, 100.0]`. If `NaN` or invalid, falls back to `defaultPoints` (50.0).
  - Sanitizes `initialContinuousWorkMinutes` to non-negative finite range.
  - Validates `lastSavedTime`: if $\le 0.0$ or $> Date().timeIntervalSince1970$, ignores offline break calculation.
- `evaluateWorkTick(isProductiveApp: Bool, tickDurationMinutes: Double)`:
  - Guards `tickDurationMinutes`: must be finite, $\ge 0.0$.
- `applyOfflineBreak(minutes: Double)`:
  - Guards `minutes`: must be finite, $\ge 0.0$.
  - Awards `5.0 * minutes` points, capped at 100.0.
- `setChargingState(_ isCharging: Bool)`:
  - Transitions to/from charging state. While charging, avoids duplicate point inflation if offline break is tracked.
- `triggerPetInteraction()`:
  - Cancels any existing dismissal timer task before starting a new 2.0-second dismissal timer.

### `ActivityMonitorService` ↔ Sleep & Idle Observers
- `handleSystemSleepOrLock()`:
  - If `sleepRecordedAt == nil`, sets `sleepRecordedAt = telemetry.now()`. Preserves existing timestamp if already asleep.
- `handleSystemWakeOrUnlock()`:
  - Calculates `elapsedMinutes = telemetry.now().timeIntervalSince(slept) / 60.0`.
  - Clears `sleepRecordedAt = nil`.
  - If `elapsedMinutes > 2.0`, calls `engine.applyOfflineBreak(minutes: elapsedMinutes)`.
  - Resets `isOnBreak = false` and `breakStartedAt = nil` so sample tick does not re-apply the same break.

## Code Layout
- `src/Executable/main.swift`: App bootstrap.
- `src/App/BitzApp.swift`: SwiftUI app, menu bar, delegate.
- `src/App/Window/MascotOverlayPanel.swift`: Floating NSPanel, positioning, observer tokens.
- `src/Services/WellnessPointEngine.swift`: PTS state machine, point clamping, Rive synchronization, persistence.
- `src/Services/ActivityMonitorService.swift`: Activity sampling, idle/break tracking, hardware sensors, browser tab inspection.
- `src/Services/MachCompatibility.swift`: Mach port deallocation helper.
- `src/Views/MascotOverlayView.swift`: SwiftUI vector avatar renderer.
- `Tests/BitzTests/WellnessPointEngineTests.swift`: PTS engine unit tests and edge-case suites.
- `Tests/BitzTests/ActivityMonitorServiceTests.swift`: Telemetry and monitoring tests.
- `Tests/BitzTests/MascotOverlayPanelTests.swift`: Geometry and overlay panel tests.
- `docs/STATE_MACHINE.md`: Detailed specification of states, transitions, invariants, and 8+ edge case scenarios.
- `docs/ARCHITECTURE.md`: Architecture overview.
- `docs/ACCEPTANCE_CRITERIA.md`: Requirements and acceptance criteria.
- `REPORT.md`: Repository improvement report (R1 & R2).
