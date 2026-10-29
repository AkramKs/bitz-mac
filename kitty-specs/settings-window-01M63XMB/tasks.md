# Tasks: Dedicated Settings Window & Streamlined Menu Bar Dropdown

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Work Package WP01: Settings Window Manager & Host Architecture

**Goal**: Establish a robust, single-instance macOS window controller to host the settings UI without interfering with the floating mascot panel.
**Prompt**: `/tasks/WP01-settings-window-manager.md`
**Requirement Refs**: FR-001, FR-003, NFR-001, C-002, C-003
**Dependencies**: none

### Included Subtasks
- T001: Implement `@MainActor public final class SettingsWindowManager: ObservableObject` in `src/App/Settings/SettingsWindowManager.swift` using `NSWindowController` and `NSHostingController`.
- T002: Ensure single-instance window lifecycle: activate existing window on repeat triggers without creating duplicate window instances.
- T003: Configure window attributes (titled, closable, miniaturizable, centered, non-floating, standard window level) ensuring `MascotOverlayPanel` remains strictly separate and non-activating.
- T004: Unit tests for `SettingsWindowManager` lifecycle, window instantiation, and repeat focus calls.

---

## Work Package WP02: Modular Settings Tab Views Implementation

**Goal**: Build the modular tab views for General, Behaviors, AI Agents, Telemetry, and Advanced settings, connecting them to existing stores.
**Prompt**: `/tasks/WP02-settings-tab-views.md`
**Requirement Refs**: FR-004, FR-005, FR-006, FR-007, FR-008, NFR-002, NFR-004
**Dependencies**: WP01

### Included Subtasks
- T005: Create `SettingsRootView` with a native macOS tabbed container layout.
- T006: Implement `GeneralSettingsTabView` with scale sliders/steppers, opacity controls, corner anchor selectors, and multi-display routing options.
- T007: Implement `BehaviorSettingsTabView` with work/break thresholds and application productivity classification management.
- T008: Implement `AgentsSettingsTabView` with AI agent popup toggles, agent catalog list, and hook installer actions.
- T009: Implement `TelemetrySettingsTabView` with metric checkboxes, HUD/bubble placement toggles, polling intervals, and warning thresholds.
- T010: Implement `AdvancedSettingsTabView` with diagnostic state simulation triggers, keyboard shortcuts cheatsheet, automatic update toggles, and Launch at Login.
- T011: Unit tests for settings tab components and two-way store binding persistence.

---

## Work Package WP03: Streamlined Menu Bar Dropdown & Shortcut Binding

**Goal**: Refactor `BitzMenuBarContentView` to eliminate visual clutter and bind the "Settings..." action.
**Prompt**: `/tasks/WP03-streamlined-menu-bar.md`
**Requirement Refs**: FR-002, FR-003, NFR-003
**Dependencies**: WP01, WP02

### Included Subtasks
- T012: Refactor `BitzMenuBarContentView` in `src/App/BitzApp.swift` to remove deep configuration submenus.
- T013: Retain essential glanceable items: status header (PTS & focus streak), "Pet Bitz", "Unlock/Lock Position", active warning cards, "Check for Updates", and "Quit Bitz".
- T014: Add "Settings... [⌘,]" menu button connecting to `SettingsWindowManager.shared.showSettingsWindow(...)`.
- T015: Support standard `⌘,` key equivalent to summon settings.
- T016: Verify vertical height stays well under 300 pt.

---

## Work Package WP04: Quality Verification & Invariant Enforcement

**Goal**: Full deterministic test execution, invariant checks, and release packaging validation.
**Prompt**: `/tasks/WP04-quality-verification.md`
**Requirement Refs**: C-001, NFR-001, NFR-002, NFR-003
**Dependencies**: WP01, WP02, WP03

### Included Subtasks
- T017: Run `xcrun swift test` and ensure all tests pass with zero failures.
- T018: Verify `MascotOverlayPanel.ignoresMouseEvents` invariant remains `true` throughout settings interactions.
- T019: Verify zero keyboard focus stealing from external apps when mascot is idle.
- T020: Package and test locally with `./Scripts/package_and_run.sh release` to confirm live AppKit & SwiftUI execution.
