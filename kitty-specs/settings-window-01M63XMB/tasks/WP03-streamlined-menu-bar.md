---
work_package_id: WP03
title: Streamlined Menu Bar Dropdown & Shortcut Binding
dependencies:
- WP01
- WP02
requirement_refs:
- FR-002
- FR-003
- NFR-003
planning_base_branch: feat/issue-49-settings-window
merge_target_branch: feat/issue-49-settings-window
branch_strategy: Planning artifacts for this mission were generated on feat/issue-49-settings-window. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/issue-49-settings-window unless the human explicitly redirects the landing branch.
subtasks:
- T012
- T013
- T014
- T015
- T016
phase: Phase 3 - Menu Integration
history: []
authoritative_surface: src/App/
create_intent:
- src/App/BitzApp.swift
- Tests/BitzTests/BitzMenuBarContentViewTests.swift
execution_mode: code_change
owned_files:
- src/App/BitzApp.swift
- Tests/BitzTests/BitzMenuBarContentViewTests.swift
tags: []
task_type: implement
tracker_refs: []
---

# Work Package Prompt: WP03 – Streamlined Menu Bar Dropdown & Shortcut Binding

## Objectives & Success Criteria
Satisfies: FR-002, FR-003, NFR-003 (see spec.md).

## Subtasks
- **T012**: Refactor `BitzMenuBarContentView` in `src/App/BitzApp.swift` to remove deep configuration submenus.
- **T013**: Retain essential glanceable items: status header (PTS & focus streak), "Pet Bitz", "Unlock/Lock Position", active warning cards, "Check for Updates", and "Quit Bitz".
- **T014**: Add "Settings... [⌘,]" menu button connecting to `SettingsWindowManager.shared.showSettingsWindow(...)`.
- **T015**: Support standard `⌘,` key equivalent to summon settings.
- **T016**: Verify vertical height stays well under 300 pt.

## Notes & Risks
Do not break existing quick actions (Pet Bitz, Lock Position).
