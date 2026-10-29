---
work_package_id: WP02
title: Modular Settings Tab Views Implementation
dependencies:
- WP01
requirement_refs:
- FR-004
- FR-005
- FR-006
- FR-007
- FR-008
- NFR-002
- NFR-004
planning_base_branch: feat/issue-49-settings-window
merge_target_branch: feat/issue-49-settings-window
branch_strategy: Planning artifacts for this mission were generated on feat/issue-49-settings-window. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/issue-49-settings-window unless the human explicitly redirects the landing branch.
subtasks:
- T005
- T006
- T007
- T008
- T009
- T010
- T011
phase: Phase 2 - Views
history: []
authoritative_surface: src/Views/Settings/
create_intent:
- src/Views/Settings/SettingsRootView.swift
- src/Views/Settings/GeneralSettingsTabView.swift
- src/Views/Settings/BehaviorSettingsTabView.swift
- src/Views/Settings/AgentsSettingsTabView.swift
- src/Views/Settings/TelemetrySettingsTabView.swift
- src/Views/Settings/AdvancedSettingsTabView.swift
- Tests/BitzTests/SettingsViewsTests.swift
execution_mode: code_change
owned_files:
- src/Views/Settings/SettingsRootView.swift
- src/Views/Settings/GeneralSettingsTabView.swift
- src/Views/Settings/BehaviorSettingsTabView.swift
- src/Views/Settings/AgentsSettingsTabView.swift
- src/Views/Settings/TelemetrySettingsTabView.swift
- src/Views/Settings/AdvancedSettingsTabView.swift
- Tests/BitzTests/SettingsViewsTests.swift
tags: []
task_type: implement
tracker_refs: []
---

# Work Package Prompt: WP02 – Modular Settings Tab Views Implementation

## Objectives & Success Criteria
Satisfies: FR-004, FR-005, FR-006, FR-007, FR-008, NFR-002, NFR-004 (see spec.md).

## Subtasks
- **T005**: Create `SettingsRootView` with a native macOS tabbed container layout.
- **T006**: Implement `GeneralSettingsTabView` with scale sliders/steppers, opacity controls, corner anchor selectors, and multi-display routing options.
- **T007**: Implement `BehaviorSettingsTabView` with work/break thresholds and application productivity classification management.
- **T008**: Implement `AgentsSettingsTabView` with AI agent popup toggles, agent catalog list, and hook installer actions.
- **T009**: Implement `TelemetrySettingsTabView` with metric checkboxes, HUD/bubble placement toggles, polling intervals, and warning thresholds.
- **T010**: Implement `AdvancedSettingsTabView` with diagnostic state simulation triggers, keyboard shortcuts cheatsheet, automatic update toggles, and Launch at Login.
- **T011**: Unit tests for settings tab components and two-way store binding persistence.

## Notes & Risks
Use standard macOS TabView styling and ensure immediate live binding to stores without UI lag.
