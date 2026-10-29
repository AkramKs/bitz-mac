---
work_package_id: WP01
title: Settings Window Manager & Host Architecture
dependencies: []
requirement_refs:
- FR-001
- FR-003
- NFR-001
- C-002
- C-003
planning_base_branch: feat/issue-49-settings-window
merge_target_branch: feat/issue-49-settings-window
branch_strategy: Planning artifacts for this mission were generated on feat/issue-49-settings-window. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/issue-49-settings-window unless the human explicitly redirects the landing branch.
subtasks:
- T001
- T002
- T003
- T004
phase: Phase 1 - Architecture
history: []
authoritative_surface: src/App/Settings/
create_intent:
- src/App/Settings/SettingsWindowManager.swift
- Tests/BitzTests/SettingsWindowManagerTests.swift
execution_mode: code_change
owned_files:
- src/App/Settings/SettingsWindowManager.swift
- Tests/BitzTests/SettingsWindowManagerTests.swift
tags: []
task_type: implement
tracker_refs: []
---

# Work Package Prompt: WP01 – Settings Window Manager & Host Architecture

## Objectives & Success Criteria
Satisfies: FR-001, FR-003, NFR-001, C-002, C-003 (see spec.md).

## Subtasks
- **T001**: Implement `@MainActor public final class SettingsWindowManager: ObservableObject` in `src/App/Settings/SettingsWindowManager.swift` using `NSWindowController` and `NSHostingController`.
- **T002**: Ensure single-instance window lifecycle: activate existing window on repeat triggers without creating duplicate window instances.
- **T003**: Configure window attributes (titled, closable, miniaturizable, centered, non-floating, standard window level) ensuring `MascotOverlayPanel` remains strictly separate and non-activating.
- **T004**: Unit tests for `SettingsWindowManager` lifecycle, window instantiation, and repeat focus calls.

## Notes & Risks
Ensure `MascotOverlayPanel.ignoresMouseEvents` invariant remains `true` at all times.
