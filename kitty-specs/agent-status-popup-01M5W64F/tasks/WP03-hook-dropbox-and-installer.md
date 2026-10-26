---
work_package_id: WP03
title: Hook Drop-box Channel & Hook Installer
dependencies:
- WP01
requirement_refs:
- FR-003
- FR-004
- FR-005
- FR-009
- NFR-001
- NFR-003
- NFR-004
planning_base_branch: feat/agent-status-popup
merge_target_branch: feat/agent-status-popup
branch_strategy: Planning artifacts for this mission were generated on feat/agent-status-popup. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/agent-status-popup unless the human explicitly redirects the landing branch.
subtasks:
- T011
- T012
- T013
- T014
phase: Phase 2 - Detection
history: []
authoritative_surface: src/Services/
create_intent:
- src/Services/DropboxAgentAdapter.swift
- src/Services/AgentHookInstaller.swift
- Tests/BitzTests/DropboxAgentAdapterTests.swift
- Tests/BitzTests/AgentHookInstallerTests.swift
- docs/agent-dropbox-event.schema.json
execution_mode: code_change
owned_files:
- src/Services/DropboxAgentAdapter.swift
- src/Services/AgentHookInstaller.swift
- Tests/BitzTests/DropboxAgentAdapterTests.swift
- Tests/BitzTests/AgentHookInstallerTests.swift
- docs/agent-dropbox-event.schema.json
tags: []
task_type: implement
tracker_refs: []
---

# Work Package Prompt: WP03 – Hook Drop-box Channel & Hook Installer

## Objectives & Success Criteria

Satisfies: FR-003, FR-004, FR-005, FR-009, NFR-001, NFR-003, NFR-004 (see spec.md).

## Subtasks

- **T011**: Write drop-box event JSON schema in `docs/agent-dropbox-event.schema.json`
- **T012**: Implement `DropboxAgentAdapter` watching `~/Library/Application Support/Bitz/agent-events/` via `DispatchSource`, consuming and deleting event files, dropping stale events
- **T013**: Implement `AgentHookInstaller` for Claude Code (`Notification`, `Stop`) and Codex (`notify`): diff preview, backup, install, uninstall
- **T014**: Unit tests using temp directories for event parsing, staleness, malformed files, installer idempotency and uninstall

## Notes & Risks

Installer edits user config files: must be opt-in, backed up, reversible. Never read agent content.

## Definition of Done

- `swift build` and `swift test` pass with new tests.
- No new macOS permissions requested (NFR-003).

## Review Feedback

*(Empty initially.)*
