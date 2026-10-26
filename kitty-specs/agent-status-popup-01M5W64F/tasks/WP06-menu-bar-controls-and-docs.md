---
work_package_id: WP06
title: Menu Bar Controls, Custom Agents & Docs
dependencies:
- WP01
- WP03
- WP04
requirement_refs:
- FR-007
- FR-008
- FR-009
planning_base_branch: feat/agent-status-popup
merge_target_branch: feat/agent-status-popup
branch_strategy: Planning artifacts for this mission were generated on feat/agent-status-popup. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/agent-status-popup unless the human explicitly redirects the landing branch.
subtasks:
- T022
- T023
- T024
- T025
phase: Phase 5 - Controls & Docs
history: []
authoritative_surface: src/App/
create_intent: []
execution_mode: code_change
owned_files:
- src/App/BitzApp.swift
- README.md
tags: []
task_type: implement
tracker_refs: []
---

# Work Package Prompt: WP06 – Menu Bar Controls, Custom Agents & Docs

## Objectives & Success Criteria

Satisfies: FR-007, FR-008, FR-009 (see spec.md).

## Subtasks

- **T022**: Add 'AI Agents' menu section: per-agent toggles, popups on/off
- **T023**: Add custom agent entry (process name or bundle ID, optional log path)
- **T024**: Add install/uninstall hook actions with confirmation and result message
- **T025**: Update README feature list and privacy notes

## Notes & Risks

Group under one submenu to avoid clutter.

## Definition of Done

- `swift build` and `swift test` pass with new tests.
- No new macOS permissions requested (NFR-003).

## Review Feedback

*(Empty initially.)*
