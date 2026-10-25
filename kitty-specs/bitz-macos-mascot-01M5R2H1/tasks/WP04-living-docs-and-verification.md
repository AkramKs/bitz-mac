---
work_package_id: WP04
title: Living Documentation & Acceptance Verification
dependencies:
- WP01
- WP02
- WP03
requirement_refs:
- FR-007
planning_base_branch: feat/bitz-macos-mascot
merge_target_branch: feat/bitz-macos-mascot
branch_strategy: Planning artifacts for this mission were generated on feat/bitz-macos-mascot. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/bitz-macos-mascot unless the human explicitly redirects the landing branch.
subtasks:
- T016
- T017
- T018
- T019
phase: Phase 4 - Living Documentation & Final Quality Gate
history:
- at: '2026-10-24T23:21:06Z'
  actor: system
  action: Prompt generated via /spec-kitty.tasks
agent_profile: implementer-ivan
authoritative_surface: docs/
create_intent:
- docs/ARCHITECTURE.md
- docs/STATE_MACHINE.md
- docs/ACCEPTANCE_CRITERIA.md
execution_mode: code_change
model: ''
owned_files:
- docs/ARCHITECTURE.md
- docs/STATE_MACHINE.md
- docs/ACCEPTANCE_CRITERIA.md
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

# Work Package Prompt: WP04 – Living Documentation & Acceptance Verification

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field in frontmatter above (or in `status.events.jsonl`).
- **If `has_feedback`**: Scroll to the **Review Feedback** section at the bottom of this document and address every item first.

---

## Review Feedback

*(Empty initially. Populated by `/spec-kitty.review` if the work package is rejected.)*

---

## Objectives & Success Criteria

1. **Architecture Documentation (`docs/ARCHITECTURE.md`)**:
   - Document the 3-layer system architecture:
     1. Window & Presentation Layer (`MascotOverlayPanel`, `MascotOverlayView`, `BitzAppDelegate`, `BitzApp`)
     2. Reactive State & Animation Bridge (`WellnessPointEngine`, `BitzState`, `BitzRiveControllable`, `ProductionRiveController`, `SpyRiveController`)
     3. System Telemetry Layer (`ActivityMonitorService`, `ActivityTelemetryProviding`, `SystemActivityTelemetryProvider`)
   - Document Swift 6 `@MainActor` strict concurrency isolation, App Sandbox privacy compliance (`C-003`), and zero wallpaper modification invariant (`C-001`, `DIR-002`).
2. **State Machine Documentation (`docs/STATE_MACHINE.md`)**:
   - Document the exact `BitzStateMachine` Rive inputs (`speedMultiplier`, `visorColor`, `isStandby`, `isGlitching`, `triggerPet`), `BitzVisorColor` float mapping (`0.0`=Cyan, `1.0`=Magenta, `2.0`=Amber, `3.0`=Red), wellness scoring formulas (`+0.5` productive tick, `-1.5` unproductive tick, `+5.0 * minutes` offline break when `minutes > 10.0`), state threshold intervals (`80.0...100.0`, `40.0..<80.0`, `15.0..<40.0`, `< 15.0`), and `.overheating` thermal override/restoration rules.
3. **Acceptance Criteria Documentation (`docs/ACCEPTANCE_CRITERIA.md`)**:
   - Map `FR-001`–`FR-007`, `NFR-001`–`NFR-004`, `C-001`–`C-004`, and `SC-001`–`SC-004` to implemented source files, unit test methods (`WellnessPointEngineTests`, `ActivityMonitorServiceTests`, `MascotOverlayPanelTests`), and verification commands.
4. **End-to-End Verification (`T019`)**:
   - Execute `swift build`, `swift test --enable-code-coverage`, and coverage inspection to confirm `>= 80%` unit test coverage on `WellnessPointEngine` and `ActivityMonitorService` (`NFR-004`, `DIR-004`).

---

## Context & Constraints

- **Spec & Design References**:
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/spec.md` (`FR-007`, `SC-001`–`SC-004`)
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/plan.md` (`IC-04`)
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/contracts/overlay-window-contract.md`
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/contracts/rive-state-machine-contract.md`
- **Project Directives**:
  - `DIR-005` / `DIRECTIVE_037`: Keep `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, and `docs/ACCEPTANCE_CRITERIA.md` synchronized with implementation changes.
- **Branch Strategy**:
  - Current branch at workflow start: `feat/bitz-macos-mascot`
  - Planning/base branch: `feat/bitz-macos-mascot`
  - Merge target branch: `feat/bitz-macos-mascot`

---

## Subtasks & Detailed Guidance

### Subtask T016 – Author `docs/ARCHITECTURE.md`

- **Purpose**: Provide authoritative architectural documentation synchronized with `src/App/`, `src/Views/`, and `src/Services/`.
- **Steps**:
  1. Create `docs/ARCHITECTURE.md`.
  2. Include component diagram (Mermaid), module responsibilities, `MascotOverlayPanel` window properties table, Swift 6 concurrency design, and privacy/performance budgets (`< 2%` CPU, `< 70MB` RAM, `0ms` click-through latency).
- **Files**: `docs/ARCHITECTURE.md`

---

### Subtask T017 – Author `docs/STATE_MACHINE.md`

- **Purpose**: Document the `BitzStateMachine` contract and `WellnessPointEngine` scoring rules for developers and Rive animators.
- **Steps**:
  1. Create `docs/STATE_MACHINE.md`.
  2. Document all 5 `BitzState` cases, point intervals, Rive input table (`speedMultiplier`, `visorColor`, `isStandby`, `isGlitching`, `triggerPet`), state diagram (Mermaid), work tick & offline break equations, and thermal override recovery behavior.
- **Files**: `docs/STATE_MACHINE.md`

---

### Subtask T018 – Author `docs/ACCEPTANCE_CRITERIA.md`

- **Purpose**: Provide a complete traceability matrix and verification checklist for `FR-001`–`FR-007`, `NFR-001`–`NFR-004`, `C-001`–`C-004`, and `SC-001`–`SC-004`.
- **Steps**:
  1. Create `docs/ACCEPTANCE_CRITERIA.md`.
  2. Include requirement-to-test traceability table, automated verification commands, and manual verification checklist.
- **Files**: `docs/ACCEPTANCE_CRITERIA.md`

---

### Subtask T019 – Execute End-to-End Build, Test, Coverage & Compliance Verification

- **Purpose**: Verify the entire codebase and documentation suite meet every quality gate in the Charter and Specification.
- **Steps**:
  1. Run `swift build` and confirm zero warnings.
  2. Run `swift test --enable-code-coverage` and confirm all tests in `WellnessPointEngineTests`, `ActivityMonitorServiceTests`, and `MascotOverlayPanelTests` pass.
  3. Inspect code coverage via `xcrun llvm-cov report` on the test binary to confirm `>= 80%` coverage on `WellnessPointEngine.swift` and `ActivityMonitorService.swift`.
  4. Verify zero forbidden APIs (`setDesktopImageURL`, `AXIsProcessTrusted`, `tapCreate`) exist in `src/`.
- **Files**: `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, `docs/ACCEPTANCE_CRITERIA.md`

---

## Test Strategy

Run:
```bash
swift test --enable-code-coverage
```
All unit tests must pass and all three documentation files in `docs/` must exist and match the implemented codebase.

---

## Definition of Done Checklist

- [ ] `docs/ARCHITECTURE.md` created and synchronized with `src/`.
- [ ] `docs/STATE_MACHINE.md` created and synchronized with `BitzStateMachine` and `WellnessPointEngine`.
- [ ] `docs/ACCEPTANCE_CRITERIA.md` created with complete traceability matrix.
- [ ] `swift test --enable-code-coverage` passes with `>= 80%` coverage on `WellnessPointEngine` and `ActivityMonitorService`.

---

## Verification Guidance

1. Verify `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, and `docs/ACCEPTANCE_CRITERIA.md` are non-empty and accurate.
2. Run `swift test --enable-code-coverage` and verify exit code `0`.

---

## Activity Log

- 2026-10-24T23:21:06Z – system – Prompt created via `/spec-kitty.tasks`.
