---
work_package_id: WP05
title: Spikes & Other-Agent Adapters (Gemini, Antigravity, Cursor, Windsurf, Copilot)
dependencies:
- WP01
- WP03
requirement_refs:
- FR-006
- C-004
planning_base_branch: feat/agent-status-popup
merge_target_branch: feat/agent-status-popup
branch_strategy: Planning artifacts for this mission were generated on feat/agent-status-popup. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/agent-status-popup unless the human explicitly redirects the landing branch.
subtasks:
- T018
- T019
- T020
- T021
phase: Phase 4 - Breadth
history: []
authoritative_surface: src/Services/
create_intent:
- docs/agent-research.md
- src/Services/LogWatcherAgentAdapter.swift
- Tests/BitzTests/LogWatcherAgentAdapterTests.swift
execution_mode: code_change
owned_files:
- docs/agent-research.md
- src/Services/LogWatcherAgentAdapter.swift
- Tests/BitzTests/LogWatcherAgentAdapterTests.swift
tags: []
task_type: implement
tracker_refs: []
---

# Work Package Prompt: WP05 – Spikes & Other-Agent Adapters (Gemini, Antigravity, Cursor, Windsurf, Copilot)

## Objectives & Success Criteria

Satisfies: FR-006, C-004 (see spec.md).

## Subtasks

- **T018**: Run spikes S1-S4 (Gemini, Antigravity, Codex notify payload, Cursor/Windsurf/Copilot) and record findings in `docs/agent-research.md`
- **T019**: Implement `LogWatcherAgentAdapter` for agents with viable log/state signals
- **T020**: Document agents that remain process-level only
- **T021**: Unit tests with sample log fixtures

## Notes & Risks

Undocumented formats may change; always fall back to process-level.

## Definition of Done

- `swift build` and `swift test` pass with new tests.
- No new macOS permissions requested (NFR-003).

## Review Feedback

*(Empty initially.)*
