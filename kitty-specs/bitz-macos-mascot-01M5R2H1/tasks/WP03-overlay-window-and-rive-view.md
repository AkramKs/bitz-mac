---
work_package_id: WP03
title: MascotOverlayPanel, MascotOverlayView & BitzApp Lifecycle
dependencies:
- WP01
- WP02
requirement_refs:
- FR-001
- FR-004
- FR-006
planning_base_branch: feat/bitz-macos-mascot
merge_target_branch: feat/bitz-macos-mascot
branch_strategy: Planning artifacts for this mission were generated on feat/bitz-macos-mascot. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/bitz-macos-mascot unless the human explicitly redirects the landing branch.
subtasks:
- T011
- T012
- T013
- T014
- T015
phase: Phase 3 - Desktop Overlay Presentation & App Lifecycle
history:
- at: '2026-10-24T23:21:06Z'
  actor: system
  action: Prompt generated via /spec-kitty.tasks
agent_profile: implementer-ivan
authoritative_surface: src/App/
create_intent:
- src/App/Window/MascotOverlayPanel.swift
- src/App/BitzApp.swift
- src/Views/MascotOverlayView.swift
- Tests/BitzTests/MascotOverlayPanelTests.swift
execution_mode: code_change
model: ''
owned_files:
- src/App/Window/MascotOverlayPanel.swift
- src/App/BitzApp.swift
- src/Views/MascotOverlayView.swift
- Tests/BitzTests/MascotOverlayPanelTests.swift
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

# Work Package Prompt: WP03 – MascotOverlayPanel, MascotOverlayView & BitzApp Lifecycle

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field in frontmatter above (or in `status.events.jsonl`).
- **If `has_feedback`**: Scroll to the **Review Feedback** section at the bottom of this document and address every item first.

---

## Review Feedback

*(Empty initially. Populated by `/spec-kitty.review` if the work package is rejected.)*

---

## Objectives & Success Criteria

1. **MascotOverlayPanel (`src/App/Window/MascotOverlayPanel.swift`)**:
   - Subclass `NSPanel` with exact window invariants from `contracts/overlay-window-contract.md`:
     - `styleMask: [.nonactivatingPanel, .borderless]`
     - `backing: .buffered`, `defer: false`
     - `isFloatingPanel = true`
     - `level = .floating`
     - `isOpaque = false`
     - `backgroundColor = .clear`
     - `hasShadow = false`
     - `isMovableByWindowBackground = false`
     - `ignoresMouseEvents = true`
     - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`
     - `override var canBecomeKey: Bool { false }`
     - `override var canBecomeMain: Bool { false }`
   - Implement bottom-right placement helper:
     - `public static let defaultPanelSize = NSSize(width: 250, height: 250)`
     - `public static func calculateOrigin(for visibleFrame: NSRect, panelSize: NSSize = defaultPanelSize) -> NSPoint` returning `NSPoint(x: visibleFrame.maxX - panelSize.width - 20, y: visibleFrame.minY + 20)` (`maxX - 270`, `minY + 20` for `250x250`).
     - `public func positionInBottomRight(of screen: NSScreen? = NSScreen.main)` applying the calculated origin and size (`250x250`).
     - Observe `NSApplication.didChangeScreenParametersNotification` to automatically reposition when display geometry changes.
2. **MascotOverlayView (`src/Views/MascotOverlayView.swift`)**:
   - SwiftUI `View` observing `@ObservedObject var engine: WellnessPointEngine`.
   - Renders within a transparent `250x250` frame (`.frame(width: 250, height: 250)`, `.background(Color.clear)`).
   - Displays the `"SYSTEM HOT! > <"` speech bubble banner when `engine.activeSpeechBubbleText` is non-nil (`FR-004`).
   - Displays the cyberpunk Bitz mascot canvas / Rive state machine representation with reactive visor color (`Cyan` `#00F0FF`, `Magenta` `#FF007F`, `Amber` `#FFB000`, `Red` `#FF1E1E`), `"ZZZ"` standby indicator when `engine.currentState == .burnout`, and glitch visual effect when `engine.currentState == .overheating`.
3. **BitzApp & BitzAppDelegate (`src/App/BitzApp.swift`)**:
   - Provide `@MainActor public final class BitzAppDelegate: NSObject, NSApplicationDelegate` and `public struct BitzApp: App` (using `MenuBarExtra` so the user can view Bitz's current state/points and click `"Pet Bitz"` to invoke `engine.triggerPetInteraction()`, `FR-006`).
4. **MascotOverlayPanelTests (`Tests/BitzTests/MascotOverlayPanelTests.swift`)**:
   - Instantiate `MascotOverlayPanel` on `@MainActor` and verify all window invariants (`isOpaque == false`, `backgroundColor == .clear`, `hasShadow == false`, `level == .floating`, `ignoresMouseEvents == true`, `canBecomeKey == false`, `canBecomeMain == false`, `collectionBehavior`, `styleMask`) and `calculateOrigin(for:)` geometry math.

---

## Context & Constraints

- **Spec & Design References**:
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/spec.md` (`FR-001`, `FR-004`, `FR-006`, `NFR-002`, `NFR-003`, `C-001`)
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/plan.md` (`IC-03`)
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/contracts/overlay-window-contract.md`
  - `kitty-specs/bitz-macos-mascot-01M5R2H1/contracts/rive-state-machine-contract.md`
- **Project Directives**:
  - `DIR-001`: `MascotOverlayPanel` must remain a borderless, transparent, floating, non-activating `NSPanel` with `ignoresMouseEvents = true` across all spaces.
  - `DIR-002`: Never replace or modify the user's macOS desktop wallpaper (`NSWorkspace.shared.setDesktopImageURL` is strictly forbidden).
- **Branch Strategy**:
  - Current branch at workflow start: `feat/bitz-macos-mascot`
  - Planning/base branch: `feat/bitz-macos-mascot`
  - Merge target branch: `feat/bitz-macos-mascot`

---

## Subtasks & Detailed Guidance

### Subtask T011 – Implement `MascotOverlayPanel` (`NSPanel` Subclass)

- **Purpose**: Enforce the click-through, transparent, floating desktop overlay contract (`FR-001`, `DIR-001`).
- **Steps**:
  1. Create `src/App/Window/MascotOverlayPanel.swift`.
  2. Implement `@MainActor public final class MascotOverlayPanel: NSPanel`.
  3. Set all window properties in `public init(contentRect: NSRect = NSRect(x: 0, y: 0, width: 250, height: 250))` matching `contracts/overlay-window-contract.md`.
  4. Override `public override var canBecomeKey: Bool { false }` and `public override var canBecomeMain: Bool { false }`.
- **Files**: `src/App/Window/MascotOverlayPanel.swift`

---

### Subtask T012 – Implement Bottom-Right Screen Frame Calculation & Screen Change Observer

- **Purpose**: Anchor Bitz at `maxX - 270`, `minY + 20` of `NSScreen.main?.visibleFrame` (`250x250` pt) and keep Bitz anchored across resolution or Dock geometry changes.
- **Steps**:
  1. Add `public static func calculateOrigin(for visibleFrame: NSRect, panelSize: NSSize = defaultPanelSize) -> NSPoint`:
     ```swift
     NSPoint(
         x: visibleFrame.maxX - panelSize.width - 20.0,
         y: visibleFrame.minY + 20.0
     )
     ```
  2. Add `public func positionInBottomRight(of screen: NSScreen? = NSScreen.main)` which reads `screen?.visibleFrame`, calculates the origin, and calls `setFrame(NSRect(origin: origin, size: Self.defaultPanelSize), display: true)`.
  3. Register an observer for `NSApplication.didChangeScreenParametersNotification` in `init` (and clean up or use weak self closure) that calls `positionInBottomRight()`.
- **Files**: `src/App/Window/MascotOverlayPanel.swift`

---

### Subtask T013 – Implement `MascotOverlayView` (`250x250` Canvas, Visor Glow, Thermal Speech Bubble)

- **Purpose**: Render Bitz's cyberpunk silhouette, LED visor state colors, `"ZZZ"` standby indicator, and `"SYSTEM HOT! > <"` thermal warning speech bubble (`FR-001`, `FR-003`, `FR-004`).
- **Steps**:
  1. Create `src/Views/MascotOverlayView.swift`.
  2. Implement `public struct MascotOverlayView: View` taking `@ObservedObject public var engine: WellnessPointEngine`.
  3. Render the optional speech bubble banner at the top of the `250x250` canvas whenever `let speech = engine.activeSpeechBubbleText` is non-nil (`"SYSTEM HOT! > <"`).
  4. Render the matte-charcoal Bitz cyber-cat vector/Rive representation with state-reactive LED visor color (`Cyan`, `Magenta`, `Amber`, `Red`), ear/tail neon accents, and `"ZZZ"` visor badge when `engine.currentState == .burnout`.
  5. Enforce `.frame(width: 250, height: 250)` and `.background(Color.clear)` with `.allowsHitTesting(false)`.
- **Files**: `src/Views/MascotOverlayView.swift`

---

### Subtask T014 – Implement `BitzApp`, `BitzAppDelegate`, and `MenuBarExtra`

- **Purpose**: Wire `WellnessPointEngine`, `ActivityMonitorService`, and `MascotOverlayPanel` into the macOS application lifecycle and provide a non-intrusive Menu Bar status item for `"Pet Bitz"` (`FR-006`).
- **Steps**:
  1. Create `src/App/BitzApp.swift`.
  2. Implement `@MainActor public final class BitzAppDelegate: NSObject, NSApplicationDelegate`:
     - Owns `public let engine: WellnessPointEngine`
     - Owns `public let activityMonitor: ActivityMonitorService`
     - Owns `public private(set) var overlayPanel: MascotOverlayPanel?`
     - Implement `public func setupOverlayPanel()` which creates `MascotOverlayPanel`, sets `contentView = NSHostingView(rootView: MascotOverlayView(engine: engine))`, positions it in bottom-right, and calls `orderFrontRegardless()`.
  3. Implement `public struct BitzApp: App` (do NOT mark with `@main` if `BitzCore` is compiled as a library target in `swift test`—or guard `@main` cleanly if needed; note that `BitzCore` is a library target in `Package.swift` so keeping `BitzApp: App` public without `@main` attribute avoids SPM library `@main` compiler errors while allowing `BitzAppDelegate` and `BitzApp` to be directly unit-tested!).
- **Files**: `src/App/BitzApp.swift`

---

### Subtask T015 – Write `MascotOverlayPanelTests` Verifying Window Invariants & Geometry

- **Purpose**: Automatically verify every invariant in `contracts/overlay-window-contract.md` and `FR-001`.
- **Steps**:
  1. Create `Tests/BitzTests/MascotOverlayPanelTests.swift`.
  2. Write `@MainActor final class MascotOverlayPanelTests: XCTestCase` testing:
     - `panel.isOpaque == false`
     - `panel.backgroundColor == .clear`
     - `panel.hasShadow == false`
     - `panel.level == .floating`
     - `panel.isFloatingPanel == true`
     - `panel.ignoresMouseEvents == true`
     - `panel.isMovableByWindowBackground == false`
     - `panel.canBecomeKey == false`
     - `panel.canBecomeMain == false`
     - `panel.styleMask.contains(.borderless)` and `panel.styleMask.contains(.nonactivatingPanel)`
     - `panel.collectionBehavior.contains([.canJoinAllSpaces, .fullScreenAuxiliary, .stationary])`
     - `MascotOverlayPanel.calculateOrigin(for: NSRect(x: 0, y: 40, width: 1920, height: 1040))` equals `NSPoint(x: 1650, y: 60)` (`1920 - 270 = 1650`, `40 + 20 = 60`).
     - `BitzAppDelegate.setupOverlayPanel()` initializes `overlayPanel` with `MascotOverlayView` hosting view.
- **Files**: `Tests/BitzTests/MascotOverlayPanelTests.swift`

---

## Test Strategy

Run:
```bash
swift test --enable-code-coverage --filter MascotOverlayPanelTests
```
Confirm all window invariant and geometry tests pass with zero warnings.

---

## Definition of Done Checklist

- [ ] `src/App/Window/MascotOverlayPanel.swift` satisfies all `contracts/overlay-window-contract.md` properties.
- [ ] `src/Views/MascotOverlayView.swift` renders the `250x250` transparent mascot view and `"SYSTEM HOT! > <"` thermal warning banner.
- [ ] `src/App/BitzApp.swift` wires `WellnessPointEngine`, `ActivityMonitorService`, `MascotOverlayPanel`, and `MenuBarExtra`.
- [ ] `Tests/BitzTests/MascotOverlayPanelTests.swift` passes all tests.
- [ ] Zero wallpaper modification APIs (`setDesktopImageURL`) exist anywhere in the codebase.

---

## Verification Guidance

1. Run `swift test --enable-code-coverage`.
2. Run `grep -rn "setDesktopImageURL" src/` and confirm zero matches.

---

## Activity Log

- 2026-10-24T23:21:06Z – system – Prompt created via `/spec-kitty.tasks`.
