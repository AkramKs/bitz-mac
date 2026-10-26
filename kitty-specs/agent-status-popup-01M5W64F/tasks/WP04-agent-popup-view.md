---
work_package_id: WP04
title: Agent Popup Rendering in Overlay
dependencies:
- WP01
requirement_refs:
- FR-003
- FR-004
- C-001
planning_base_branch: feat/agent-status-popup
merge_target_branch: feat/agent-status-popup
branch_strategy: Planning artifacts for this mission were generated on feat/agent-status-popup. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/agent-status-popup unless the human explicitly redirects the landing branch.
subtasks:
- T015
- T016
- T017
phase: Phase 3 - UI
history: []
authoritative_surface: src/Views/
create_intent: []
execution_mode: code_change
owned_files:
- src/Views/MascotOverlayView.swift
tags: []
task_type: implement
tracker_refs: []
---

# Work Package Prompt: WP04 – Agent Popup Rendering in Overlay

## Objectives & Success Criteria

Satisfies: FR-003, FR-004, C-001 (see spec.md).

## Subtasks

- **T015**: Render `AgentMonitorService.activeAgentPopup` in the overlay with distinct working/approval/done styles
- **T016**: Give agent popup priority over wellness speech bubble text; restore wellness text afterwards
- **T017**: Verify overlay stays click-through and non-activating; popup visible across Spaces and full screen

## Notes & Risks

Do not modify WellnessPointEngine bubble logic.

## Definition of Done

- `swift build` and `swift test` pass with new tests.
- No new macOS permissions requested (NFR-003).

## Review Feedback

*(Empty initially.)*
