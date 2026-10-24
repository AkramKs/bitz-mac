# Phase 0 Research: Bitz the Cyber Cat macOS Desktop Companion

**Mission**: `bitz-macos-mascot-01M5R2H1`  
**Branch**: `feat/bitz-macos-mascot`  
**Date**: 2026-10-25

---

## 1. Transparent Click-Through Windowing on macOS 14+

- **Decision**: Subclass `NSPanel` as `MascotOverlayPanel` configured with `styleMask: [.nonactivatingPanel, .borderless]`, `level = .floating`, `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`, `isMovableByWindowBackground = false`, `ignoresMouseEvents = true`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, and `canBecomeKey` / `canBecomeMain` returning `false`.
- **Rationale**:
  - `NSPanel` with `.nonactivatingPanel` prevents macOS from activating the companion app or stealing focus from the user's active IDE/browser.
  - `ignoresMouseEvents = true` is enforced at the WindowServer compositing layer, guaranteeing zero click interception (`PROJECT_002`).
  - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` keeps Bitz anchored in the bottom-right corner (`maxX - 270`, `minY + 20` of `NSScreen.main.visibleFrame`) across Mission Control Spaces and full-screen apps.
- **Alternatives Considered**:
  - *Standard `NSWindow` with SwiftUI `.windowStyle(.hiddenTitleBar)`*: Rejected because `NSWindow` can still become key/main and lacks `.nonactivatingPanel` semantics.
  - *Desktop Wallpaper Modification (`NSWorkspace.setDesktopImageURL`)*: Strictly prohibited by `PROJECT_002` and `DIR-002`.

---

## 2. Rive Animation Bridge & Protocol Abstraction (`BitzRiveBridge`)

- **Decision**: Introduce a `@MainActor` protocol `BitzRiveControllable` (with default production adapter + lightweight SwiftUI vector canvas fallback) that wraps the `BitzStateMachine` Rive inputs (`speedMultiplier`, `visorColor`, `isStandby`, `isGlitching`, `triggerPet`).
- **Rationale**:
  - Enables `MascotOverlayView` and `WellnessPointEngine` to synchronize all five `BitzStateMachine` inputs deterministically in unit tests without requiring a GPU context or binary `bitz_mascot.riv` file during `swift test`.
  - Prevents force-unwrap crashes (`try!`) if `bitz_mascot.riv` is not yet bundled in the resource bundle (`SG-SWIFT-001`), while rendering a high-craft vector representation of Bitz (matte-white/dark-gray cyber cat, neon cyan inner ears, glossy LED visor with `^ ^`, `- -`, `> <`, `ZZZ`, `! !` eyes, and floating tail) when running without the `.riv` binary.
  - Keeps `swift build` and `swift test` fast, deterministic, and offline-capable while preserving the exact `BitzStateMachine` parameter contract required by animators.
- **Alternatives Considered**:
  - *Hardcoding `RiveViewModel(fileName: "bitz_mascot")` directly in `MascotOverlayView`*: Rejected because missing `.riv` resources cause runtime crashes and slow down headless CI tests.

---

## 3. System Activity, Idle Time & Thermal Telemetry (`ActivityMonitorService`)

- **Decision**: Implement `ActivityMonitorService` as a `@MainActor` service with injectable telemetry providers (`WorkspaceActivityProviding`, `IdleTimeProviding`, `ThermalStateProviding`) that defaults to macOS system APIs:
  - Active app detection: `NSWorkspace.shared.frontmostApplication?.bundleIdentifier`
  - Idle time detection: `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)` plus `NSWorkspace.screensDidSleepNotification` / `screensDidWakeNotification` and `DistributedNotificationCenter` screen lock notifications (`com.apple.screenIsLocked` / `com.apple.screenIsUnlocked`)
  - Thermal monitoring: `ProcessInfo.processInfo.thermalState` (`ProcessInfo.thermalStateDidChangeNotification`) plus injectable CPU temperature readings (`> 80.0°C` threshold)
- **Rationale**:
  - Polling at a `60.0` second interval (`Timer.publish` / Swift concurrency task loop) with event-driven sleep/wake/thermal notifications uses virtually `0%` CPU (`< 0.1%` overhead), keeping well within the `< 2%` Apple Silicon CPU budget (`NFR-001`).
  - Dependency-injected protocols allow deterministic TDD unit testing of `ActivityMonitorService` at `>= 80%` coverage (`NFR-003`) without mocking global AppKit singletons.
- **Alternatives Considered**:
  - *High-frequency IOKit / SMC polling every 100ms*: Rejected because rapid SMC polling wastes CPU cycles and risks App Sandbox / notarization issues when `ProcessInfo.thermalState` and 60s ticks suffice.

---

## 4. Supply-Chain Security & Adversarial Evidence (`051-supply-chain-install-safety`)

- **Decision**: Keep the core Swift Package (`Package.swift`) zero-external-dependency by default for deterministic builds and unit testing, while providing optional/conditional `RiveRuntime` (`https://github.com/rive-app/rive-ios`) integration via the `BitzRiveControllable` adapter seam.
- **Supply-Chain Assessment**:
  - **Registry Authenticity**: Swift Package Manager resolves packages directly from signed Git tags over HTTPS.
  - **Lifecycle Scripts**: SwiftPM does not execute arbitrary `preinstall`/`postinstall` shell scripts (unlike npm/pip), eliminating install-time script execution vectors.
  - **Adversarial Finding & Disposition**:
    - *Finding*: Pulling a large precompiled binary XCFramework (`RiveRuntime`) unconditionally during every `swift test` run increases supply-chain surface and can break offline/sandboxed builds if network access is restricted.
    - *Disposition (`changed`)*: Decoupled `BitzStateMachine` parameter binding behind `BitzRiveControllable` so the core executable and test targets build and pass 100% offline using pure Apple system frameworks (`SwiftUI`, `AppKit`, `CoreGraphics`, `Foundation`), while `RiveRuntime` can be linked seamlessly when the `.riv` asset is dropped in.
