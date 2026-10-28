---
work_package_id: WP02
title: Process Detection Adapter (Baseline)
dependencies:
- WP01
requirement_refs:
- FR-001
- FR-010
- NFR-001
- NFR-002
planning_base_branch: feat/agent-status-popup
merge_target_branch: feat/agent-status-popup
branch_strategy: Planning artifacts for this mission were generated on feat/agent-status-popup. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/agent-status-popup unless the human explicitly redirects the landing branch.
subtasks:
- T006
- T007
- T008
- T009
- T010
phase: Phase 2 - Detection
history: []
authoritative_surface: src/Services/
create_intent:
- src/Services/ProcessAgentAdapter.swift
- Tests/BitzTests/ProcessAgentAdapterTests.swift
execution_mode: code_change
owned_files:
- src/Services/ProcessAgentAdapter.swift
- Tests/BitzTests/ProcessAgentAdapterTests.swift
tags: []
task_type: implement
tracker_refs: []
---

# Work Package Prompt: WP02 – Process Detection Adapter (Baseline)

## Objectives & Success Criteria

Satisfies: FR-001, FR-010, NFR-001, NFR-002 (see spec.md).

## Subtasks

- **T006**: Implement injectable process/bundle-ID provider using `NSWorkspace.runningApplications` and `libproc`
- **T007**: Implement `ProcessAgentAdapter`: started on appearance, exit yields generic done, matching catalog process names/bundle IDs
- **T008**: Implement working-vs-idle heuristic (CPU delta or child processes) so idle agents are not flagged working
- **T009**: Piggyback on the existing coalesced 5 s tick; verify < 1% CPU overhead
- **T010**: Unit tests with fake process lists covering start, work, idle, exit, multiple agents

## Notes & Risks

Depends on spike S5 for the heuristic; start with CPU delta threshold.

## Definition of Done

- `swift build` and `swift test` pass with new tests.
- No new macOS permissions requested (NFR-003).

## Review Feedback

*(Empty initially.)*
