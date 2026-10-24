# Phase 1 Data Model: Bitz the Cyber Cat macOS Desktop Companion

**Mission**: `bitz-macos-mascot-01M5R2H1`  
**Branch**: `feat/bitz-macos-mascot`  
**Date**: 2026-10-25

---

## 1. Domain Entities & Value Objects

### 1.1 `BitzState` (Enum)
Represents Bitz's five mutually exclusive behavioral and visual states.

```swift
public enum BitzState: String, Sendable, Equatable, CaseIterable {
    case superCharged // 80.0...100.0 pts
    case balanced     // 40.0..<80.0 pts
    case overworked   // 15.0..<40.0 pts
    case burnout      // < 15.0 pts (0.0..<15.0)
    case overheating  // System CPU > 80°C or serious/critical ThermalState (overrides point state)
}
```

### 1.2 `VisorColorCode` (Value Mapping)
Maps `BitzState` to the `BitzStateMachine` numeric input `visorColor`:

| Code (`Float`) | Color Name | Associated `BitzState` | Visor Eyes Expression |
| :--- | :--- | :--- | :--- |
| `0.0` | Cyan (Default) | `.balanced` | Happy / Blinking (`^ ^`) |
| `1.0` | Magenta (Super Charged) | `.superCharged` | Excited (`^ ^` + sparks) |
| `2.0` | Amber (Tired) | `.overworked` | Droopy (`- -`) |
| `3.0` | Red (Critical / Hot) | `.overheating` | Panicked (`! !` / `> <`) |
| *(Standby)* | Dimmed / ZZZ | `.burnout` (`isStandby = true`) | Sleeping (`ZZZ`) |

### 1.3 `RiveStateInputs` (Value Object)
Immutable snapshot of the exact inputs sent to the Rive `BitzStateMachine`:

| Field | Type | Range / Values | Description |
| :--- | :--- | :--- | :--- |
| `speedMultiplier` | `Float` | `0.0...2.5` | Controls idle bobbing and ear/tail animation speed. |
| `visorColor` | `Float` | `0.0, 1.0, 2.0, 3.0` | Selects LED visor color & eye expression. |
| `isStandby` | `Bool` | `true` / `false` | Collapses Bitz into loaf mode with `"ZZZ"` visor when `true`. |
| `isGlitching` | `Bool` | `true` / `false` | Triggers jitter/sweat thermal alert animation when `true`. |
| `petTriggerCount` | `Int` | `>= 0` | Monotonically increments each time `triggerPet` is fired. |

---

## 2. Core Stateful Components

### 2.1 `WellnessPointEngine` (`@MainActor ObservableObject`)

| Property | Access | Type | Initial Value | Invariant |
| :--- | :--- | :--- | :--- | :--- |
| `points` | `@Published public private(set)` | `Double` | `50.0` | Always clamped within `0.0...100.0`. |
| `currentState` | `@Published public private(set)` | `BitzState` | `.balanced` | Matches point band unless `isOverheatingActive == true`. |
| `speedMultiplier` | `@Published public private(set)` | `Float` | `1.0` | `2.0` (superCharged), `1.0` (balanced), `0.4` (overworked), `0.0` (burnout). |
| `visorColor` | `@Published public private(set)` | `Float` | `0.0` | `1.0` (superCharged), `0.0` (balanced), `2.0` (overworked), `3.0` (overheating). |
| `isStandby` | `@Published public private(set)` | `Bool` | `false` | `true` iff `currentState == .burnout`. |
| `isGlitching` | `@Published public private(set)` | `Bool` | `false` | `true` iff `currentState == .overheating`. |

#### State Transition Table

| Current State | Trigger / Condition | Next State | Output Parameters (`speedMultiplier`, `visorColor`, `isStandby`, `isGlitching`) |
| :--- | :--- | :--- | :--- |
| Any | `triggerThermalWarning(isOverheating: true)` | `.overheating` | `(unchanged/last, 3.0, false, true)` |
| `.overheating` | `triggerThermalWarning(isOverheating: false)` | Re-evaluated from `points` | Restored to point-band parameters |
| Non-overheating | `points` in `80.0...100.0` | `.superCharged` | `(2.0, 1.0, false, false)` |
| Non-overheating | `points` in `40.0..<80.0` | `.balanced` | `(1.0, 0.0, false, false)` |
| Non-overheating | `points` in `15.0..<40.0` | `.overworked` | `(0.4, 2.0, false, false)` |
| Non-overheating | `points < 15.0` | `.burnout` | `(0.0, unchanged/2.0, true, false)` |

#### Point Scoring Rules
1. **Productive Work Tick (`registerWorkTick(isProductiveApp: true)`)**: `points = min(100.0, max(0.0, points + 0.5))`
2. **Distraction Work Tick (`registerWorkTick(isProductiveApp: false)`)**: `points = min(100.0, max(0.0, points - 1.5))`
3. **Offline Recovery Break (`registerOfflineBreak(minutes:)`)**:
   - If `minutes > 10.0`: `points = min(100.0, points + (minutes * 5.0))`
   - If `minutes <= 10.0`: no change to `points`.

---

### 2.2 `ActivityMonitorService` (`@MainActor ObservableObject`)

| Property / Dependency | Type | Purpose |
| :--- | :--- | :--- |
| `engine` | `WellnessPointEngine` | Target engine updated on each activity/idle/thermal event. |
| `productiveBundleIDs` | `Set<String>` | Configurable set of productive macOS app bundle IDs (Xcode, VS Code, Cursor, Terminal, iTerm2, Swift, etc.). |
| `distractionBundleIDs` | `Set<String>` | Configurable set of distraction/social bundle IDs. |
| `cpuTemperatureThresholdCelsius` | `Double` | Default `80.0°C` (`> 80.0` triggers `.overheating`). |
| `offlineBreakThresholdMinutes` | `Double` | Default `10.0` minutes (`> 10.0` triggers offline break recovery). |
