---
work_package_id: WP02
title: ActivityMonitorService & Privacy-Safe System Telemetry
dependencies:
- WP01
requirement_refs:
- FR-005
planning_base_branch: feat/bitz-macos-mascot
merge_target_branch: feat/bitz-macos-mascot
branch_strategy: 'Current branch at workflow start: feat/bitz-macos-mascot. Planning/base branch for this feature: feat/bitz-macos-mascot. Completed changes must merge into feat/bitz-macos-mascot.'
subtasks:
- T006
- T007
- T008
- T009
- T010
phase: Phase 2 - System Telemetry & Break Detection
history:
- !!omap
  - at: '2026-10-24T23:21:06Z'
  - actor: system
  - action: Prompt generated via /spec-kitty.tasks
agent_profile: implementer-ivan
authoritative_surface: src/Services/ActivityMonitorService.swift
create_intent:
- src/Services/ActivityMonitorService.swift
- Tests/BitzTests/ActivityMonitorServiceTests.swift
execution_mode: code_change
model: ''
owned_files:
- src/Services/ActivityMonitorService.swift
- Tests/BitzTests/ActivityMonitorServiceTests.swift
role: implementer
tags: []
task_type: implement
tracker_refs: []
---

## ⚡ Do This First: Load Agent Profile

Before reading any further instructions or writing any code, load your agent profile by running:

```bash
spec-kitty agent profile show implementer-ivan
```

Wait for the output and internalize the persona's role, domain expertise, and quality standards. They govern how you approach every decision in this work package. If the command fails (e.g., profile not found), continue with default conduct.

---

# Work Package Prompt: WP02 – ActivityMonitorService & Privacy-Safe System Telemetry

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field in frontmatter above (or in `status.events.jsonl`).
- **If `has_feedback`**: Scroll to the **Review Feedback** section at the bottom of this document and address every item first.

---

## Review Feedback

*(Empty initially. Populated by `/spec-kitty.review` if the work package is rejected.)*

---

## Objectives & Success Criteria

1. **Telemetry Provider Seam (`src/Services/ActivityMonitorService.swift`)**:
   - Define `@MainActor public protocol ActivityTelemetryProviding` exposing:
     - `func frontmostBundleIdentifier() -> String?`
     - `func secondsSinceLastInput() -> TimeInterval`
     - `func thermalState() -> ProcessInfo.ThermalState`
     - `func cpuTemperatureCelsius() -> Double?`
     - `func now() -> Date`
   - Implement `@MainActor public struct SystemActivityTelemetryProvider: ActivityTelemetryProviding` using `NSWorkspace.shared.frontmostApplication?.bundleIdentifier`, `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)`, and `ProcessInfo.processInfo.thermalState`.
2. **Productive Bundle ID Classification (`src/Services/ActivityMonitorService.swift`)**:
   - Default productive bundle ID set:
     - `"com.apple.dt.Xcode"`
     - `"com.microsoft.VSCode"`
     - `"com.apple.Terminal"`
     - `"com.googlecode.iterm2"`
     - `"com.todesktop.230313mzl4w4u92"` (Cursor)
     - `"dev.warp.Warp-Stable"`
     - `"com.jetbrains.intellij"`
   - Provide `public func isProductiveBundleID(_ bundleID: String?) -> Bool`.
3. **ActivityMonitorService Polling, Idle Break Detection & Thermal Monitoring**:
   - Implement `@MainActor public final class ActivityMonitorService`:
     - Holds reference to `engine: WellnessPointEngine` and `telemetry: ActivityTelemetryProviding`.
     - `public private(set) var isMonitoring: Bool = false`
     - `public private(set) var isOnBreak: Bool = false`
     - `public private(set) var breakStartedAt: Date? = nil`
     - `public let idleBreakThresholdSeconds: TimeInterval` (default `60.0`)
     - `public let overheatingTemperatureThresholdCelsius: Double = 80.0`
     - `public func startMonitoring(intervalSeconds: TimeInterval = 5.0)` and `public func stopMonitoring()`
     - `public func performSampleTick()`:
       1. Evaluates thermal state: `let overheating = telemetry.thermalState() == .critical || telemetry.thermalState() == .serious || (telemetry.cpuTemperatureCelsius() ?? 0.0) > overheatingTemperatureThresholdCelsius`. If changed (or currently overheating), calls `engine.triggerThermalWarning(isOverheating: overheating)`.
       2. Evaluates idle duration: `let idleSeconds = telemetry.secondsSinceLastInput()`.
       3. If `idleSeconds >= idleBreakThresholdSeconds`:
          - Enters break mode (`if !isOnBreak { isOnBreak = true; breakStartedAt = telemetry.now().addingTimeInterval(-idleSeconds) }`) and skips work tick penalty/gain while idle.
       4. If `idleSeconds < idleBreakThresholdSeconds`:
          - If returning from break (`isOnBreak == true`), computes total break minutes from `breakStartedAt` to `telemetry.now()`, calls `engine.applyOfflineBreak(minutes: breakMinutes)`, and resets `isOnBreak = false`, `breakStartedAt = nil`.
          - Evaluates active app (`let productive = isProductiveBundleID(telemetry.frontmostBundleIdentifier())`) and calls `engine.evaluateWorkTick(isProductiveApp: productive)`.
4. **Unit Test Suite (`Tests/BitzTests/ActivityMonitorServiceTests.swift`)**:
   - Achieve `>= 80%` unit test coverage on `ActivityMonitorService` using a deterministic `MockTelemetryProvider`.

---

## Context & Constraints

- **Spec & Design References**:
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/spec.md` (`FR-005`, `NFR-001`, `NFR-004`, `C-003`)
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/plan.md` (`IC-02`)
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/data-model.md` (`Entity 4: ActivityMonitorService`)
- **Privacy & Sandbox Constraint (`C-003`)**:
  - Do NOT use Accessibility APIs (`AXIsProcessTrusted`, `AXUIElement`) or keylogging (`CGEvent.tapCreate`).
  - Only read foreground app bundle identifier (`NSWorkspace`) and seconds since last input (`CGEventSource`).
- **Branch Strategy**:
  - Current branch at workflow start: `feat/bitz-macos-mascot`
  - Planning/base branch: `feat/bitz-macos-mascot`
  - Merge target branch: `feat/bitz-macos-mascot`

---

## Subtasks & Detailed Guidance

### Subtask T006 – Define `ActivityTelemetryProviding` and `SystemActivityTelemetryProvider`

- **Purpose**: Decouple macOS system telemetry calls from business logic so `ActivityMonitorService` can be unit-tested deterministically without wall-clock sleeps or real window focus manipulation.
- **Steps**:
  1. Create `src/Services/ActivityMonitorService.swift`.
  2. Import `AppKit`, `CoreGraphics`, `Foundation`.
  3. Define `@MainActor public protocol ActivityTelemetryProviding` and `@MainActor public struct SystemActivityTelemetryProvider: ActivityTelemetryProviding`.
- **Files**: `src/Services/ActivityMonitorService.swift`

---

### Subtask T007 – Implement Productive Bundle ID Whitelist and `isProductiveBundleID(_:)`

- **Purpose**: Classify foreground applications into productive vs. unproductive for `WellnessPointEngine.evaluateWorkTick(isProductiveApp:)`.
- **Steps**:
  1. Define `public static let defaultProductiveBundleIDs: Set<String>` containing Xcode, VS Code, Terminal, iTerm2, Cursor, Warp, and IntelliJ bundle identifiers.
  2. Implement `public func isProductiveBundleID(_ bundleID: String?) -> Bool` returning `true` if `bundleID` is non-nil and contained in `productiveBundleIDs`, otherwise `false`.
- **Files**: `src/Services/ActivityMonitorService.swift`

---

### Subtask T008 – Implement `ActivityMonitorService` Polling & Idle-to-Active Break Restoration

- **Purpose**: Drive periodic telemetry checks, pause work ticks during user idle breaks, and restore wellness points (`+5.0` pts/min for breaks `> 10.0` minutes) when the user returns.
- **Steps**:
  1. Implement `startMonitoring(intervalSeconds:)` using a repeating `Timer` on `RunLoop.main` (with `tolerance = intervalSeconds * 0.2` for Apple Silicon energy coalescing per `NFR-001`) that invokes `performSampleTick()`.
  2. Implement `stopMonitoring()` invalidating the timer and setting `isMonitoring = false`.
  3. Implement `performSampleTick()` handling idle entry (`idleSeconds >= idleBreakThresholdSeconds`), active return (`engine.applyOfflineBreak(minutes:)`), and active work tick (`engine.evaluateWorkTick(isProductiveApp:)`).
- **Files**: `src/Services/ActivityMonitorService.swift`

---

### Subtask T009 – Implement Thermal State Evaluation in `ActivityMonitorService`

- **Purpose**: Detect CPU thermal spikes (`> 80.0°C` or `.critical`/`.serious` `ProcessInfo.ThermalState`) and trigger/clear `WellnessPointEngine.triggerThermalWarning(isOverheating:)`.
- **Steps**:
  1. Track `private var lastOverheatingState: Bool = false` inside `ActivityMonitorService`.
  2. On each `performSampleTick()`, compute `isOverheating`:
     - `telemetry.thermalState() == .critical || telemetry.thermalState() == .serious || (telemetry.cpuTemperatureCelsius() ?? 0.0) > overheatingTemperatureThresholdCelsius`
  3. When `isOverheating` is `true` or transitions from `true` to `false`, call `engine.triggerThermalWarning(isOverheating: isOverheating)` and update `lastOverheatingState`.
- **Files**: `src/Services/ActivityMonitorService.swift`

---

### Subtask T010 – Write `ActivityMonitorServiceTests` (`>= 80%` Coverage)

- **Purpose**: Verify `ActivityMonitorService` classification, break detection, thermal overrides, and timer lifecycle (`NFR-004`).
- **Steps**:
  1. Create `Tests/BitzTests/ActivityMonitorServiceTests.swift`.
  2. Implement `@MainActor final class MockTelemetryProvider: ActivityTelemetryProviding`.
  3. Write unit tests verifying:
     - Productive bundle IDs (`com.apple.dt.Xcode`, `com.microsoft.VSCode`, etc.) yield `+0.5` pts per sample tick.
     - Unproductive or nil bundle IDs (`com.apple.Safari`, `nil`) yield `-1.5` pts per sample tick.
     - Idle transition (`secondsSinceLastInput >= 60.0`) sets `isOnBreak = true` and does not deduct points while idle.
     - Returning from a short break (`5.0` minutes `<= 10.0`) resets `isOnBreak = false` without adding break bonus points, then applies the current work tick.
     - Returning from a long offline break (`12.0` minutes `> 10.0`) restores `+60.0` pts (clamped to `100.0`).
     - Thermal spike (`cpuTemperatureCelsius = 85.0` or `thermalState = .critical`) triggers `.overheating` and `"SYSTEM HOT! > <"`, and cooling down (`cpuTemperatureCelsius = 55.0`, `thermalState = .nominal`) restores the underlying state.
     - `startMonitoring()` and `stopMonitoring()` toggle `isMonitoring` cleanly.
- **Files**: `Tests/BitzTests/ActivityMonitorServiceTests.swift`

---

## Test Strategy

Run:
```bash
swift test --enable-code-coverage --filter ActivityMonitorServiceTests
```
Confirm all tests pass with zero warnings and `>= 80%` code coverage on `src/Services/ActivityMonitorService.swift`.

---

## Definition of Done Checklist

- [ ] `src/Services/ActivityMonitorService.swift` implements `ActivityTelemetryProviding`, `SystemActivityTelemetryProvider`, and `ActivityMonitorService`.
- [ ] Zero forbidden Accessibility or keylogging APIs used (`C-003`).
- [ ] `Tests/BitzTests/ActivityMonitorServiceTests.swift` passes all tests with `>= 80%` coverage.
- [ ] `swift test` passes across all targets with zero warnings.

---

## Verification Guidance

1. Run `swift test --enable-code-coverage --filter ActivityMonitorServiceTests`.
2. Run `grep -rn "AXIsProcessTrusted\|tapCreate" src/` and confirm zero matches.

---

## Activity Log

- 2026-10-24T23:21:06Z – system – Prompt created via `/spec-kitty.tasks`.
