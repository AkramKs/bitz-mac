---
work_package_id: WP01
title: Foundation, Rive Adapter Seam & WellnessPointEngine
dependencies: []
requirement_refs:
- FR-002
- FR-003
- FR-004
planning_base_branch: feat/bitz-macos-mascot
merge_target_branch: feat/bitz-macos-mascot
branch_strategy: Planning artifacts for this mission were generated on feat/bitz-macos-mascot. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/bitz-macos-mascot unless the human explicitly redirects the landing branch.
subtasks:
- T001
- T002
- T003
- T004
- T005
phase: Phase 1 - Core Domain & Rive State Bridge
history:
- at: '2026-10-24T23:21:06Z'
  actor: system
  action: Prompt generated via /spec-kitty.tasks
agent_profile: implementer-ivan
authoritative_surface: src/Services/
create_intent:
- Package.swift
- src/Services/WellnessPointEngine.swift
- Tests/BitzTests/WellnessPointEngineTests.swift
execution_mode: code_change
model: ''
owned_files:
- Package.swift
- src/Services/WellnessPointEngine.swift
- Tests/BitzTests/WellnessPointEngineTests.swift
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

# Work Package Prompt: WP01 – Foundation, Rive Adapter Seam & WellnessPointEngine

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field in frontmatter above (or in `status.events.jsonl`).
- **If `has_feedback`**: Scroll to the **Review Feedback** section at the bottom of this document and address every item first.

---

## Review Feedback

*(Empty initially. Populated by `/spec-kitty.review` if the work package is rejected.)*

---

## Objectives & Success Criteria

1. **Swift 6 Package Scaffold (`Package.swift`)**:
   - Configure `swift-tools-version: 6.0` targeting `.macOS(.v14)`.
   - Define library target `BitzCore` (rooted at `src/Services` and shared modules or `src` excluding `@main` entry point as needed, or structured cleanly so `BitzCore` contains testable services/window/views and `BitzApp` executable target links `BitzCore`).
   - Define test target `BitzTests` (`Tests/BitzTests`) depending on `BitzCore`.
2. **Domain Types & Rive Adapter Seam (`src/Services/WellnessPointEngine.swift`)**:
   - Define `public enum BitzState: String, Sendable, Equatable, CaseIterable` with cases `.superCharged`, `.balanced`, `.overworked`, `.burnout`, `.overheating`.
   - Define `public enum BitzRiveCommand: Sendable, Equatable` (`case setFloat(String, Float)`, `case setBool(String, Bool)`, `case fireTrigger(String)`).
   - Define `@MainActor public protocol BitzRiveControllable: AnyObject` with `func setInput(_ name: String, value: Float)`, `func setInput(_ name: String, value: Bool)`, `func triggerInput(_ name: String)`.
   - Implement `@MainActor public final class SpyRiveController: BitzRiveControllable` (recording `commands: [BitzRiveCommand]` and latest `floatInputs: [String: Float]`, `boolInputs: [String: Bool]`, `triggerCounts: [String: Int]`) and `@MainActor public final class ProductionRiveController: BitzRiveControllable`.
3. **WellnessPointEngine Implementation (`src/Services/WellnessPointEngine.swift`)**:
   - `@MainActor public final class WellnessPointEngine: ObservableObject`
   - `@Published public private(set) var currentPoints: Double = 50.0`
   - `@Published public private(set) var currentState: BitzState = .balanced`
   - `@Published public private(set) var activeSpeechBubbleText: String? = nil`
   - `public let maxPoints: Double = 100.0`, `public let minPoints: Double = 0.0`
   - `public func evaluateWorkTick(isProductiveApp: Bool)` (`+0.5` if `true`, `-1.5` if `false`, clamped to `0.0...100.0`, updates state & Rive inputs; if currently `.overheating`, updates `currentPoints` while keeping thermal override active until cleared).
   - `public func applyOfflineBreak(minutes: Double)` (`+5.0 * minutes` when `minutes > 10.0`, `0.0` when `minutes <= 10.0`, clamped to `0.0...100.0`, updates state & Rive inputs).
   - `public func triggerThermalWarning(isOverheating: Bool)` (when `true`, sets `currentState = .overheating`, `activeSpeechBubbleText = "SYSTEM HOT! > <"`, `isGlitching = true`, `visorColor = 3.0`; when `false`, clears speech bubble and restores point-derived `BitzState` and Rive inputs).
   - `public func triggerPetInteraction()` (fires `"triggerPet"` on `riveController`).
4. **Unit Test Suite (`Tests/BitzTests/WellnessPointEngineTests.swift`)**:
   - Achieve `>= 80%` line/branch coverage on `WellnessPointEngine`.
   - Verify all 5 `BitzState` thresholds, clamping at `0.0` and `100.0`, offline break `10.0` min threshold, exact Rive input payloads (`speedMultiplier`, `visorColor`, `isStandby`, `isGlitching`, `triggerPet`), and thermal override/recovery.

---

## Context & Constraints

- **Spec & Design References**:
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/spec.md` (`FR-002`, `FR-003`, `FR-004`, `NFR-004`, `C-002`, `C-004`)
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/plan.md` (`IC-01`)
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/data-model.md` (`Entity 1: BitzState`, `Entity 2: WellnessPointEngine`, `Entity 3: BitzRiveControllable`)
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/contracts/rive-state-machine-contract.md`
- **Project Directives**:
  - `DIR-004`: Enforce exact `BitzState` thresholds (`Super Charged` `80.0...100.0`, `Balanced` `40.0..<80.0`, `Overworked` `15.0..<40.0`, `Burnout` `< 15.0`, `Overheating` override) and `BitzStateMachine` input bindings with `>= 80%` unit test coverage.
- **Branch Strategy**:
  - Current branch at workflow start: `feat/bitz-macos-mascot`
  - Planning/base branch: `feat/bitz-macos-mascot`
  - Merge target branch: `feat/bitz-macos-mascot`

---

## Subtasks & Detailed Guidance

### Subtask T001 – Scaffold Swift 6 `Package.swift`

- **Purpose**: Provide a zero-warning Swift 6 Package Manager manifest supporting both library unit testing (`BitzCore` + `BitzTests`) and the macOS application executable (`BitzApp`).
- **Steps**:
  1. Create `Package.swift` at the repository root with `// swift-tools-version: 6.0`.
  2. Set `platforms: [.macOS(.v14)]`.
  3. Configure target `BitzCore` (`path: "src"`, `exclude: ["App/BitzApp.swift"]` or equivalent clean split so `BitzCore` compiles `src/Services`, `src/App/Window`, `src/Views` once created, and works seamlessly when only `src/Services/WellnessPointEngine.swift` exists in `WP01`).
     - *Important*: In `WP01`, `src/App/` and `src/Views/` do not exist yet unless handled cleanly. Keep `BitzCore` `path: "src"` and only put `@main` in a separate target or conditional if needed, OR set `BitzCore` `path: "src"` with `BitzApp` executable in `WP03` (or include a minimal `BitzCore` target in `Package.swift` with `path: "src"`, `exclude: ["App/BitzApp.swift"]` if `App/BitzApp.swift` exists, or even simpler: in `BitzApp.swift` (created in WP03), avoid `@main` conflict by having `BitzCore` compile `src` and invoking `BitzApp.main()` or keeping `BitzCore` `path: "src"`).
     - Best pattern for SPM `Package.swift` across `WP01`–`WP03` without `WP03` needing to edit `Package.swift` (`owned_files` of `WP01` owns `Package.swift`!):
       - Define `.library(name: "BitzCore", targets: ["BitzCore"])`
       - Define `.target(name: "BitzCore", path: "src")`
       - Define `.testTarget(name: "BitzTests", dependencies: ["BitzCore"], path: "Tests/BitzTests")`
       - That way, `src/Services/WellnessPointEngine.swift` (WP01), `src/Services/ActivityMonitorService.swift` (WP02), and `src/App/Window/MascotOverlayPanel.swift`, `src/Views/MascotOverlayView.swift`, `src/App/BitzApp.swift` (WP03) are ALL automatically compiled as part of `BitzCore` without `WP02` or `WP03` ever needing to modify `Package.swift`!
- **Files**: `Package.swift`
- **Validation**: `swift build` and `swift test` execute cleanly.

---

### Subtask T002 – Define `BitzState`, `BitzRiveCommand`, `BitzRiveControllable`, and Rive Controllers

- **Purpose**: Establish the domain state enumeration and the protocol-oriented Rive `BitzStateMachine` adapter seam required by `FR-003` and `C-004`.
- **Steps**:
  1. In `src/Services/WellnessPointEngine.swift`, define:
     ```swift
     public enum BitzState: String, Sendable, Equatable, CaseIterable {
         case superCharged
         case balanced
         case overworked
         case burnout
         case overheating
     }
     ```
  2. Define `BitzRiveInputName` constants matching `contracts/rive-state-machine-contract.md`:
     - `speedMultiplier = "speedMultiplier"`
     - `visorColor = "visorColor"`
     - `isStandby = "isStandby"`
     - `isGlitching = "isGlitching"`
     - `triggerPet = "triggerPet"`
  3. Define `BitzVisorColor` float constants:
     - `cyan: Float = 0.0`
     - `magenta: Float = 1.0`
     - `amber: Float = 2.0`
     - `red: Float = 3.0`
  4. Define `BitzRiveCommand`, `@MainActor public protocol BitzRiveControllable: AnyObject`, `@MainActor public final class SpyRiveController: BitzRiveControllable`, and `@MainActor public final class ProductionRiveController: BitzRiveControllable`.
- **Files**: `src/Services/WellnessPointEngine.swift`

---

### Subtask T003 – Implement `WellnessPointEngine` Work Ticks, Offline Breaks & `syncWithRive()`

- **Purpose**: Implement the core wellness scoring math and state machine synchronization (`FR-002`, `FR-003`).
- **Steps**:
  1. Implement `@MainActor public final class WellnessPointEngine: ObservableObject`.
  2. Initialize `currentPoints: Double = 50.0`, `currentState: BitzState = .balanced`, `activeSpeechBubbleText: String? = nil`.
  3. Implement `evaluateWorkTick(isProductiveApp: Bool)`:
     - `let delta = isProductiveApp ? 0.5 : -1.5`
     - `currentPoints = min(max(currentPoints + delta, minPoints), maxPoints)`
     - If `!isOverheatingOverride`, call `evaluateState()`.
  4. Implement `applyOfflineBreak(minutes: Double)`:
     - Guard `minutes > 10.0` else return.
     - `let restoredPoints = minutes * 5.0`
     - `currentPoints = min(currentPoints + restoredPoints, maxPoints)`
     - If `!isOverheatingOverride`, call `evaluateState()`.
  5. Implement `evaluateState()` and `syncWithRive()`:
     - `80.0...100.0` -> `.superCharged` (`speedMultiplier = 2.0`, `visorColor = 1.0`, `isGlitching = false`, `isStandby = false`)
     - `40.0..<80.0` -> `.balanced` (`speedMultiplier = 1.0`, `visorColor = 0.0`, `isGlitching = false`, `isStandby = false`)
     - `15.0..<40.0` -> `.overworked` (`speedMultiplier = 0.4`, `visorColor = 2.0`, `isGlitching = false`, `isStandby = false`)
     - `< 15.0` -> `.burnout` (`speedMultiplier = 0.0`, `isStandby = true`, `isGlitching = false`)
     - `.overheating` -> (`isGlitching = true`, `visorColor = 3.0`)
- **Files**: `src/Services/WellnessPointEngine.swift`

---

### Subtask T004 – Implement `triggerThermalWarning(isOverheating:)` & `triggerPetInteraction()`

- **Purpose**: Support CPU thermal spike overrides (`FR-004`) with `"SYSTEM HOT! > <"` speech bubble and pet trigger (`FR-006`).
- **Steps**:
  1. Track `private var isOverheatingOverride: Bool = false`.
  2. In `triggerThermalWarning(isOverheating: Bool)`:
     - If `isOverheating == true`:
       - Set `isOverheatingOverride = true`
       - Set `currentState = .overheating`
       - Set `activeSpeechBubbleText = "SYSTEM HOT! > <"`
       - Call `syncWithRive()` (sends `isGlitching = true`, `visorColor = 3.0`).
     - If `isOverheating == false`:
       - Set `isOverheatingOverride = false`
       - Set `activeSpeechBubbleText = nil`
       - Call `evaluateState()` to recompute the point-based `BitzState` and call `syncWithRive()`.
  3. In `triggerPetInteraction()`:
     - Call `riveController?.triggerInput("triggerPet")`.
- **Files**: `src/Services/WellnessPointEngine.swift`

---

### Subtask T005 – Write `WellnessPointEngineTests` (`>= 80%` Coverage)

- **Purpose**: Validate every requirement of `FR-002`, `FR-003`, `FR-004`, and `NFR-004`.
- **Steps**:
  1. Create `Tests/BitzTests/WellnessPointEngineTests.swift`.
  2. Write `@MainActor final class WellnessPointEngineTests: XCTestCase` testing:
     - Initial state (`50.0` pts, `.balanced`, `speedMultiplier == 1.0`, `visorColor == 0.0`, `isStandby == false`, `isGlitching == false`).
     - Productive work tick (`+0.5`) and clamping at `100.0`.
     - Unproductive work tick (`-1.5`) and clamping at `0.0`.
     - Exact threshold boundaries: `80.0` (`.superCharged`), `79.9` (`.balanced`), `40.0` (`.balanced`), `39.9` (`.overworked`), `15.0` (`.overworked`), `14.9` (`.burnout`).
     - Offline break: `minutes = 10.0` (`0` pts added), `minutes = 10.1` (`+50.5` pts added), `minutes = 20.0` (`+100.0` clamped to `100.0`).
     - Thermal warning override (`triggerThermalWarning(isOverheating: true)` sets `.overheating`, `activeSpeechBubbleText == "SYSTEM HOT! > <"`, `isGlitching == true`, `visorColor == 3.0`) and recovery (`triggerThermalWarning(isOverheating: false)` clears `activeSpeechBubbleText` and restores point-derived state).
     - `triggerPetInteraction()` increments `triggerPet` count on `SpyRiveController`.
- **Files**: `Tests/BitzTests/WellnessPointEngineTests.swift`

---

## Test Strategy

Run:
```bash
swift test --enable-code-coverage --filter WellnessPointEngineTests
```
All tests in `WellnessPointEngineTests` must pass with zero compiler warnings and `>= 80%` coverage on `src/Services/WellnessPointEngine.swift`.

---

## Definition of Done Checklist

- [ ] `Package.swift` compiles cleanly with Swift 6 (`swift-tools-version: 6.0`) on macOS 14.0+.
- [ ] `src/Services/WellnessPointEngine.swift` implements `BitzState`, `BitzRiveControllable`, `SpyRiveController`, `ProductionRiveController`, and `WellnessPointEngine`.
- [ ] `Tests/BitzTests/WellnessPointEngineTests.swift` passes all unit tests with `>= 80%` coverage.
- [ ] Zero compiler warnings or Swift 6 concurrency errors.

---

## Verification Guidance

1. Run `swift build` and confirm exit code `0` with no warnings.
2. Run `swift test --enable-code-coverage --filter WellnessPointEngineTests` and confirm all tests pass.

---

## Activity Log

- 2026-10-24T23:21:06Z – system – Prompt created via `/spec-kitty.tasks`.
