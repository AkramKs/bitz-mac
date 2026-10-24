# Bitz macOS Mascot — Project Charter

<!--
Curated human-readable companion to `.kittify/charter/charter.yaml`.
Captures the architectural rationale, invariants, and governance policies for
"Bitz the Cyber Cat" (macOS Wellness & PC Health Desktop Companion).
-->

## 1. Project Intent & Scope

**Bitz the Cyber Cat** is a native macOS 14.0+ wellness and PC health desktop companion built with **Swift 6**, **SwiftUI**, **AppKit**, **CoreGraphics**, and **RiveRuntime** (Metal-accelerated vector animation).

- **Overlay Presentation (`MascotOverlayPanel`)**: Bitz renders inside a borderless, transparent, non-activating `NSPanel` (`level = .floating`, `ignoresMouseEvents = true`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`).
- **Wallpaper Invariant**: The application is strictly a transparent desktop overlay and **must never** replace or modify the user's macOS desktop wallpaper.
- **State & Wellness Engine (`WellnessPointEngine`)**:
  - **Super Charged (`80...100` pts)**: `speedMultiplier = 2.0`, `visorColor = 1.0` (Magenta), particle sparks.
  - **Balanced (`40..<80` pts)**: `speedMultiplier = 1.0`, `visorColor = 0.0` (Cyan).
  - **Overworked (`15..<40` pts)**: `speedMultiplier = 0.4`, `visorColor = 2.0` (Amber).
  - **Burnout (`<15` pts)**: `speedMultiplier = 0.0`, `isStandby = true` (loaf/ZZZ visor).
  - **Overheating (`>80°C` CPU thermals)**: `isGlitching = true`, `visorColor = 3.0` (Red), thermal alert speech bubble.
- **Scoring Rules**:
  - Productive app focus tick: `+0.5` points (capped at `100.0`).
  - Distraction/social app tick: `-1.5` points (floored at `0.0`).
  - Offline/idle break (`>10` minutes idle or screen lock): `+5.0` points per minute.

## 2. Testing & Coverage Policy

| Policy | Value |
|---|---|
| Minimum Coverage | 80%+ coverage on core services (`WellnessPointEngine`, `ActivityMonitorService`) |
| Methodology | TDD required (`tdd-red-green-refactor`, `acceptance-test-first`) |
| Test Framework | Swift Testing / XCTest (`swift test` / `xcodebuild test`) |
| Type & Concurrency Checking | Swift 6 strict concurrency (`swiftc -strict-concurrency=complete`) |

## 3. Quality Gates & Performance Budgets

- **Static Analysis**: `SwiftLint` with zero compiler warnings.
- **Runtime Resource Cap**:
  - `< 2%` CPU usage on Apple Silicon during idle and 60 FPS Rive animation playback.
  - `< 70MB` RAM footprint.
  - CLI operations complete in `< 2 seconds`.
- **Review & Merge**: Feature branches merged into `main` using `conventional commits` with `1 approval` and verification against `docs/ACCEPTANCE_CRITERIA.md`.

## 4. Project Directives & Risk Boundaries

1. **DIR-001 (error) — Transparent Click-Through Overlay Invariant**: `MascotOverlayPanel` must always configure `.nonactivatingPanel`, `.borderless`, `isOpaque = false`, `backgroundColor = .clear`, and `ignoresMouseEvents = true`. Mouse clicks must pass directly through to underlying windows.
2. **DIR-002 (error) — Zero Wallpaper Modification**: Never invoke `NSWorkspace.shared.setDesktopImageURL` or alter user desktop wallpaper settings under any circumstance.
3. **DIR-003 (error) — Hardware Resource Budget**: Keep CPU usage below 2% on Apple Silicon and memory footprint below 70MB RAM during 60 FPS `RiveRuntime` playback.
4. **DIR-004 (error) — Rive State Machine Contract Fidelity**: `MascotOverlayView` must drive `BitzStateMachine` using the exact declared inputs (`speedMultiplier`, `visorColor`, `isStandby`, `isGlitching`, `triggerPet`) and `WellnessPointEngine` thresholds.
5. **DIR-005 (warn) — Living Documentation Synchronization**: Keep `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, and `docs/ACCEPTANCE_CRITERIA.md` synchronized with any change to windowing, wellness point scoring, or Rive inputs.

## 5. Amendment & Exception Process

- **Amendments**: Update `.kittify/charter/charter.md` and `.kittify/charter/charter.yaml`, run `spec-kitty charter generate --from-interview --force` and `spec-kitty charter synthesize`, and review diffs before merging to `main`.
- **Exceptions**: Any temporary exception to coverage or resource gates must be documented in commit/PR notes with explicit scope, mitigation, and sunset criteria.
