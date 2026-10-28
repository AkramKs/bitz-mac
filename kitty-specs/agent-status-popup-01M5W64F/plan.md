# Implementation Plan: AI Agent Status Detection & Popup

**Branch**: `feat/agent-status-popup` | **Date**: 2026-10-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/agent-status-popup-01M5W64F/spec.md` (GitHub issue #1)

## Summary

Add an `AgentMonitorService` that detects running AI agents (Claude, Gemini, Antigravity, Codex, Cursor, Windsurf, Copilot, Aider, etc.) and emits unified `AgentEvent`s (`started`, `working`, `needsApproval`, `done`). Detection is layered: process polling (universal baseline) plus optional per-agent hook/log adapters for accurate done/approval signals. Events drive a new agent popup in the existing speech-bubble path of `MascotOverlayView`, with no new macOS permissions.

## Technical Context

**Language/Version**: Swift 6.0 (swift-tools-version 6.0)
**Primary Dependencies**: SwiftUI, AppKit, Foundation (`DispatchSource` file watching, `NSWorkspace`, `libproc`); no third-party deps
**Storage**: `UserDefaults` for agent enable flags and custom agents; event drop-box directory `~/Library/Application Support/Bitz/agent-events/` (JSON files)
**Testing**: XCTest in `Tests/BitzTests` (existing target); adapters tested with injected process lists and temp directories
**Target Platform**: macOS 14+, Apple Silicon
**Project Type**: single (Swift package: `BitzCore` library + `Bitz` executable)
**Performance Goals**: hook events shown ≤ 2 s; process changes ≤ 5 s (NFR-001)
**Constraints**: < 1% avg CPU (NFR-002); no Accessibility/screen-capture permissions (NFR-003); click-through overlay stays non-interactive (C-001)
**Scale/Scope**: ~12 built-in agents, user-defined extras; one new service, one model file, one view change, menu additions

## Charter Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Privacy-first, zero-permission stance (README): PASS. Uses process listing and files the user's own tools write; no content read, no scraping (C-003).
- Click-through, non-activating overlay: PASS. Popup is display-only (C-001).
- Existing 5 s sampling cadence / low overhead: PASS. Process poll piggybacks on a coalesced timer; file watching is event-driven.
- Re-check after design: hook installer modifies user config files, so it must be opt-in, reversible and backed up (FR-009).

## Design Decisions

1. **Event model** (`AgentEvent`, `AgentEventKind`, `AgentDefinition`) in `src/Models/AgentModels.swift`, `Sendable`, `Codable`.
2. **Adapters** behind `AgentAdapter` protocol:
   - `ProcessAdapter`: polls running processes/bundle IDs; "working" is inferred from CPU delta or child processes to avoid flagging idle agents; process exit yields `done` (generic).
   - `DropboxAdapter`: watches the event drop-box directory; hook scripts write one JSON event per file `{agent, kind, message, ts}`. Stale (> 60 s) events are discarded (NFR-004).
   - `LogWatcherAdapter`: watches configured log/state paths for agents without hooks (Gemini, Antigravity, Cursor, Windsurf, Copilot), added only after spike results.
3. **Hook strategy**: Claude Code `Notification` and `Stop` hooks and the Codex `notify` setting call a tiny shell snippet that writes a drop-box event. Installer shows a diff, backs up the original config, and supports uninstall.
4. **Popup**: `AgentMonitorService` publishes `activeAgentPopup` (text, kind, expiry). `WellnessPointEngine` bubble logic stays untouched; `MascotOverlayView` shows the agent popup with priority over wellness text, with distinct styles (working/approval/done). Approval popups persist until the next event or timeout; done popups auto-dismiss after ~6 s.
5. **Agent catalog**: built-in `AgentDefinition` list as data (NFR-005); custom agents stored in `UserDefaults` and merged at runtime.
6. **Menu bar**: new "AI Agents" section in [BitzApp.swift](../../src/App/BitzApp.swift): per-agent toggles, popups on/off, add custom agent, install/uninstall hooks.
7. **Degradation**: agents without signals show running/stopped only, labeled in the menu.

## Research / Spikes (Phase 0)

| Spike | Question | Blocks |
|-------|----------|--------|
| S1 | Gemini CLI: hooks or log/telemetry files exposing done/approval? | FR-006 |
| S2 | Antigravity: state/log files under `~/.gemini/antigravity/` usable? | FR-006 |
| S3 | Codex `notify` payload format | FR-006 |
| S4 | Cursor, Windsurf, Copilot: any local log/state signal? | FR-006 |
| S5 | Reliable "working vs idle" heuristic for process adapter | FR-001 |

Outcome documented in `research.md`; any agent without a viable signal stays at process-level (C-004).

## Project Structure

### Documentation (this mission)

```
kitty-specs/agent-status-popup-01M5W64F/
├── plan.md
├── research.md          # spike results
├── data-model.md
├── quickstart.md
├── contracts/           # drop-box event JSON schema
└── tasks.md             # created by /spec-kitty.tasks
```

### Source Code (repository root)

```
src/
├── App/BitzApp.swift                    # menu bar "AI Agents" section
├── Models/AgentModels.swift             # new: AgentEvent, AgentDefinition
├── Services/
│   ├── AgentMonitorService.swift        # new: orchestrates adapters, publishes popup
│   ├── AgentAdapters.swift              # new: Process/Dropbox/LogWatcher adapters
│   ├── AgentHookInstaller.swift         # new: Claude/Codex hook install/uninstall
│   └── WellnessPointEngine.swift        # unchanged (bubble priority handled in view)
└── Views/MascotOverlayView.swift        # agent popup rendering

Tests/BitzTests/
├── AgentMonitorServiceTests.swift
├── AgentAdaptersTests.swift
└── AgentHookInstallerTests.swift
```

**Structure Decision**: Extend the existing single Swift package. New code lives in `BitzCore` (`src/`), with a new `src/Models` folder.

## Complexity Tracking

No charter violations.

## Implementation Concern Map

### IC-01 — Agent model, catalog and event bus

- **Purpose**: Define unified events and the data-driven agent catalog.
- **Relevant requirements**: FR-002, FR-007, NFR-005
- **Affected surfaces**: `src/Models/AgentModels.swift`, `AgentMonitorService.swift`
- **Sequencing/depends-on**: none
- **Risks**: Over-designing; keep catalog as plain data.

### IC-02 — Process detection baseline

- **Purpose**: Detect running agents and working/idle with low CPU.
- **Relevant requirements**: FR-001, FR-010, NFR-001, NFR-002
- **Affected surfaces**: `AgentAdapters.swift`
- **Sequencing/depends-on**: IC-01
- **Risks**: False "working" for idle agents; process names differ per install method.

### IC-03 — Drop-box hook channel and installer

- **Purpose**: Accurate done/approval signals for Claude Code and Codex.
- **Relevant requirements**: FR-003, FR-004, FR-005, FR-009, NFR-003, NFR-004
- **Affected surfaces**: `AgentAdapters.swift`, `AgentHookInstaller.swift`
- **Sequencing/depends-on**: IC-01
- **Risks**: Editing user config files; must be opt-in, backed up and reversible.

### IC-04 — Popup rendering

- **Purpose**: Show working/approval/done popups in the overlay.
- **Relevant requirements**: FR-003, FR-004, C-001
- **Affected surfaces**: `MascotOverlayView.swift`, `AgentMonitorService.swift`
- **Sequencing/depends-on**: IC-01
- **Risks**: Conflict with existing wellness speech bubbles; define priority.

### IC-05 — Other-agent adapters (spike-gated)

- **Purpose**: Extend accurate signals to Gemini, Antigravity, Cursor, Windsurf, Copilot.
- **Relevant requirements**: FR-006, C-004
- **Affected surfaces**: `AgentAdapters.swift`, `research.md`
- **Sequencing/depends-on**: IC-01, IC-03; spikes S1–S4
- **Risks**: Undocumented formats may change; fall back to process-level.

### IC-06 — Menu bar controls

- **Purpose**: Per-agent toggles, custom agents, hook install/uninstall.
- **Relevant requirements**: FR-007, FR-008, FR-009
- **Affected surfaces**: `src/App/BitzApp.swift`
- **Sequencing/depends-on**: IC-01, IC-03
- **Risks**: Menu clutter; group under one submenu.
