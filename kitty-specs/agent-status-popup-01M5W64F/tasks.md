# Tasks: AI Agent Status Detection & Popup

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Work Package WP01: Agent Model, Catalog & AgentMonitorService Core

**Goal**: Foundation for all other packages. Keep catalog as plain data; no UI code here.
**Prompt**: `/tasks/WP01-agent-model-catalog-and-service.md`
**Requirement Refs**: FR-002, FR-007, NFR-005
**Dependencies**: none

### Included Subtasks
T001 Define `AgentEventKind` (started/working/needsApproval/done), `AgentEvent`, `AgentDefinition` (Codable, Sendable) in `src/Models/AgentModels.swift`
T002 Add data-driven built-in catalog (Claude, Gemini, Antigravity, Codex/ChatGPT, Cursor, Windsurf, Copilot, Aider, Goose, OpenCode, Amp, Cline) and UserDefaults-backed custom agents
T003 Define `AgentAdapter` protocol and implement `@MainActor AgentMonitorService` (ObservableObject) merging adapter events, publishing `activeAgentPopup` (text, kind, expiry) and running agents
T004 Implement popup lifetime rules: done auto-dismiss ~6 s, approval persists until next event, discard events older than 60 s
T005 Unit tests with a fake adapter and injectable clock

## Work Package WP02: Process Detection Adapter (Baseline)

**Goal**: Depends on spike S5 for the heuristic; start with CPU delta threshold.
**Prompt**: `/tasks/WP02-process-detection-adapter.md`
**Requirement Refs**: FR-001, FR-010, NFR-001, NFR-002
**Dependencies**: WP01

### Included Subtasks
T006 Implement injectable process/bundle-ID provider using `NSWorkspace.runningApplications` and `libproc`
T007 Implement `ProcessAgentAdapter`: started on appearance, exit yields generic done, matching catalog process names/bundle IDs
T008 Implement working-vs-idle heuristic (CPU delta or child processes) so idle agents are not flagged working
T009 Piggyback on the existing coalesced 5 s tick; verify < 1% CPU overhead
T010 Unit tests with fake process lists covering start, work, idle, exit, multiple agents

## Work Package WP03: Hook Drop-box Channel & Hook Installer

**Goal**: Installer edits user config files: must be opt-in, backed up, reversible. Never read agent content.
**Prompt**: `/tasks/WP03-hook-dropbox-and-installer.md`
**Requirement Refs**: FR-003, FR-004, FR-005, FR-009, NFR-001, NFR-003, NFR-004
**Dependencies**: WP01

### Included Subtasks
T011 Write drop-box event JSON schema in `docs/agent-dropbox-event.schema.json`
T012 Implement `DropboxAgentAdapter` watching `~/Library/Application Support/Bitz/agent-events/` via `DispatchSource`, consuming and deleting event files, dropping stale events
T013 Implement `AgentHookInstaller` for Claude Code (`Notification`, `Stop`) and Codex (`notify`): diff preview, backup, install, uninstall
T014 Unit tests using temp directories for event parsing, staleness, malformed files, installer idempotency and uninstall

## Work Package WP04: Agent Popup Rendering in Overlay

**Goal**: Do not modify WellnessPointEngine bubble logic.
**Prompt**: `/tasks/WP04-agent-popup-view.md`
**Requirement Refs**: FR-003, FR-004, C-001
**Dependencies**: WP01

### Included Subtasks
T015 Render `AgentMonitorService.activeAgentPopup` in the overlay with distinct working/approval/done styles
T016 Give agent popup priority over wellness speech bubble text; restore wellness text afterwards
T017 Verify overlay stays click-through and non-activating; popup visible across Spaces and full screen

## Work Package WP05: Spikes & Other-Agent Adapters (Gemini, Antigravity, Cursor, Windsurf, Copilot)

**Goal**: Undocumented formats may change; always fall back to process-level.
**Prompt**: `/tasks/WP05-other-agent-adapters-and-spikes.md`
**Requirement Refs**: FR-006, C-004
**Dependencies**: WP01, WP03

### Included Subtasks
T018 Run spikes S1-S4 (Gemini, Antigravity, Codex notify payload, Cursor/Windsurf/Copilot) and record findings in `docs/agent-research.md`
T019 Implement `LogWatcherAgentAdapter` for agents with viable log/state signals
T020 Document agents that remain process-level only
T021 Unit tests with sample log fixtures

## Work Package WP06: Menu Bar Controls, Custom Agents & Docs

**Goal**: Group under one submenu to avoid clutter.
**Prompt**: `/tasks/WP06-menu-bar-controls-and-docs.md`
**Requirement Refs**: FR-007, FR-008, FR-009
**Dependencies**: WP01, WP03, WP04

### Included Subtasks
T022 Add 'AI Agents' menu section: per-agent toggles, popups on/off
T023 Add custom agent entry (process name or bundle ID, optional log path)
T024 Add install/uninstall hook actions with confirmation and result message
T025 Update README feature list and privacy notes


> Note: plan.md's single `AgentAdapters.swift` is split into one file per adapter so work packages own disjoint files.
