---
work_package_id: WP01
title: Agent Model, Catalog & AgentMonitorService Core
dependencies: []
requirement_refs:
- FR-002
- FR-007
- NFR-005
planning_base_branch: feat/agent-status-popup
merge_target_branch: feat/agent-status-popup
branch_strategy: Planning artifacts for this mission were generated on feat/agent-status-popup. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/agent-status-popup unless the human explicitly redirects the landing branch.
subtasks:
- T001
- T002
- T003
- T004
- T005
phase: Phase 1 - Foundation
history: []
authoritative_surface: src/Models/
create_intent:
- src/Models/AgentModels.swift
- src/Services/AgentMonitorService.swift
- Tests/BitzTests/AgentMonitorServiceTests.swift
execution_mode: code_change
owned_files:
- src/Models/AgentModels.swift
- src/Services/AgentMonitorService.swift
- Tests/BitzTests/AgentMonitorServiceTests.swift
tags: []
task_type: implement
tracker_refs: []
---

# Work Package Prompt: WP01 – Agent Model, Catalog & AgentMonitorService Core

## Objectives & Success Criteria

Satisfies: FR-002, FR-007, NFR-005 (see spec.md).

## Subtasks

- **T001**: Define `AgentEventKind` (started/working/needsApproval/done), `AgentEvent`, `AgentDefinition` (Codable, Sendable) in `src/Models/AgentModels.swift`
- **T002**: Add data-driven built-in catalog (Claude, Gemini, Antigravity, Codex/ChatGPT, Cursor, Windsurf, Copilot, Aider, Goose, OpenCode, Amp, Cline) and UserDefaults-backed custom agents
- **T003**: Define `AgentAdapter` protocol and implement `@MainActor AgentMonitorService` (ObservableObject) merging adapter events, publishing `activeAgentPopup` (text, kind, expiry) and running agents
- **T004**: Implement popup lifetime rules: done auto-dismiss ~6 s, approval persists until next event, discard events older than 60 s
- **T005**: Unit tests with a fake adapter and injectable clock

## Notes & Risks

Foundation for all other packages. Keep catalog as plain data; no UI code here.

## Definition of Done

- `swift build` and `swift test` pass with new tests.
- No new macOS permissions requested (NFR-003).

## Review Feedback

*(Empty initially.)*
