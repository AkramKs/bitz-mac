---
work_package_id: WP04
title: Quality Verification & Invariant Enforcement
dependencies:
- WP01
- WP02
- WP03
requirement_refs:
- C-001
- NFR-001
- NFR-002
- NFR-003
planning_base_branch: feat/issue-49-settings-window
merge_target_branch: feat/issue-49-settings-window
branch_strategy: Planning artifacts for this mission were generated on feat/issue-49-settings-window. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/issue-49-settings-window unless the human explicitly redirects the landing branch.
subtasks:
- T017
- T018
- T019
- T020
phase: Phase 4 - Verification
history: []
authoritative_surface: Tests/
create_intent:
- Tests/BitzTests/SettingsIntegrationTests.swift
execution_mode: code_change
owned_files:
- Tests/BitzTests/SettingsIntegrationTests.swift
tags: []
task_type: implement
tracker_refs: []
---

# Work Package Prompt: WP04 – Quality Verification & Invariant Enforcement

## Objectives & Success Criteria
Satisfies: C-001, NFR-001, NFR-002, NFR-003, SC-001, SC-002, SC-003, SC-004 (see spec.md).

## Subtasks
- **T017**: Run `xcrun swift test` and ensure all tests pass with zero failures.
- **T018**: Verify `MascotOverlayPanel.ignoresMouseEvents` invariant remains `true` throughout settings interactions.
- **T019**: Verify zero keyboard focus stealing from external apps when mascot is idle.
- **T020**: Package and test locally with `./Scripts/package_and_run.sh release` to confirm live AppKit & SwiftUI execution.

## Notes & Risks
Zero regressions across existing test suite.
