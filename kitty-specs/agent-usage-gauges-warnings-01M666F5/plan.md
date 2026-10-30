# Implementation Plan: Agent Usage Gauges, "Almost Done" Milestones & Critical Warnings

**Branch**: `feat/issue-38-agent-gauges-warnings` | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/agent-usage-gauges-warnings-01M666F5/spec.md` (Tracks GitHub issue #38)

## Summary

Add three agent signals to Bitz: a context usage gauge (tokens + % per agent), "almost done" milestones, and persistent agent warnings (context threshold, tool-call loop, stall). Session-log adapters stay pure parsers that emit events and a new never-shown `usage` reading; `AgentMonitorService` owns all policy (thresholds, stall timer, single warning slot, acknowledgement, toggles). Presentation reuses existing surfaces: the speech bubble (new interactive warning style with **Got it**), the visor (amber override), the AI Agents telemetry metric (context text), and the AI Agents settings tab.

## Technical Context

**Language/Version**: Swift 6.0 (swift-tools-version 6.0, strict concurrency)  
**Primary Dependencies**: SwiftUI, AppKit, Foundation, CryptoKit (system framework, for tool-input fingerprints); no third-party dependencies  
**Storage**: `UserDefaults` (new `AgentSignalSettings` JSON blob under `Bitz.AgentMonitor.SignalSettings`, injected defaults domain); session logs read-only from `~/.claude/projects/<project>/<session>.jsonl` and `~/.gemini/antigravity/brain/<id>/.system_generated/logs/transcript.jsonl`  
**Testing**: XCTest in `Tests/BitzTests/` via `xcrun swift test`; policy tested with synthetic events + injected clock; parsers tested with JSONL fixtures written to temp dirs; isolated `UserDefaults(suiteName:)` per test  
**Target Platform**: macOS 14.0+, Apple Silicon  
**Project Type**: Single Swift package (`BitzCore` library + `Bitz` executable)  
**Performance Goals**: poll ≤ every 1.5 s per adapter; a poll with no new bytes reads 0 bytes; ≤ 256 KB read on startup/session switch; signals reach the mascot ≤ 5 s  
**Constraints**: charter < 2% CPU / < 70 MB RAM; overlay click-through and no focus stealing (AGENTS.md §2); nothing drawn outside its window; no new hooks; no transcript text retained  
**Scale/Scope**: 1 new adapter (`ClaudeCodeTranscriptAdapter`), 1 shared log-tail helper, 1 pure session tracker, monitor policy extension, 4 view touch points, 1 settings card, drop-box schema update, ~8 test files touched/added

## Charter Check

- **DIR-001 Click-through**: PASS. Only `SpeechBubblePanel` toggles clicks, and only while the warning bubble's **Got it** button is on screen, via the existing `SpeechBubbleContent.isInteractive` → `updatePanelsInteractivity()` path. `MascotOverlayPanel` unchanged.
- **DIR-002 Wallpaper**: PASS. Not touched.
- **DIR-003 Resource budget**: PASS by design. Incremental reads (`SessionLogTail`), 1.5 s polls, 256 KB seed cap, one `usage` event per poll with new bytes, 5 s stall sweep. Verified manually in WP06 with Activity Monitor during `./Scripts/package_and_run.sh release`.
- **DIR-004 Rive contract**: PASS. `WellnessPointEngine` state and `BitzStateMachine` inputs are untouched; the amber visor is a view-level override in `MascotOverlayView` reusing the existing Amber (`#FFB000`) value.
- **DIR-005 Living docs**: Planned. `docs/ARCHITECTURE.md` (new adapter + policy), `docs/STATE_MACHINE.md` (agent-warning visor override), `docs/ACCEPTANCE_CRITERIA.md` (new FR rows), `docs/agent-dropbox-event.schema.json` (new kinds + metadata).
- **Testing policy (TDD, ≥ 80% on core services)**: Planned. Every IC lists its tests; policy and parsers are pure enough to test without UI or real files.
- **DIRECTIVE_001 Separation of concerns**: PASS. Parse (adapters) → policy (monitor) → present (views); interfaces documented in [data-model.md](data-model.md) and [contracts/agent-event-contract.md](contracts/agent-event-contract.md).
- **DIRECTIVE_010 Spec fidelity**: One recorded deviation, see Complexity Tracking.

## Design Decisions

Full rationale and alternatives in [research.md](research.md).

1. **Monitor owns policy** (decision `policy_placement`). Adapters emit `working` / `done` / `warning(loop)` plus a `usage` reading; `AgentMonitorService` applies settings, thresholds, the stall timer and the warning slot. Drop-box integrators get gauges and stall detection for free.
2. **New `usage` event kind**, never shown, carrying `contextTokens`, `pendingTools`, `turnActive`, `seed`. Emitted at most once per poll that saw new bytes, so "activity" = bytes appended (FR-009).
3. **Loop detection stays in the adapter-side tracker**: the threshold is fixed at 4 (FR-008), so it needs no settings; the monitor only applies the loop toggle.
4. **Turn boundaries (Claude Code)**: `working` is emitted on the first assistant line after a prompt (avoids false turns from local slash commands); the turn ends on `stop_reason == end_turn` (emits `done`), or silently on `turn_duration` / `stop_hook_summary` system lines or a `[Request interrupted` marker. `compact_boundary` resets the loop streak.
5. **Single warning slot + approval override** (decision `cross_agent_priority`): another agent's needs-approval takes the bubble; the warning stays active (amber visor) and its bubble returns on that agent's next event.
6. **Settings live on `AgentMonitorService`** next to `popupsEnabled`, persisted through an injected `UserDefaults` (default `.standard`) so tests use isolated suites (NFR-005).
7. **Visor**: `MascotOverlayView` gains `agentMonitor` and a pure `visorColor(for:agentWarningActive:)`; overheating red wins.
8. **Gauge**: `AgentTelemetry` gains an optional `AgentContextReading`; `formattedSummary` / `compactBadge` render `Claude ctx 148k · 74%` through existing placements.

## Project Structure

### Documentation (this mission)

```
kitty-specs/agent-usage-gauges-warnings-01M666F5/
├── spec.md
├── plan.md              # This file
├── research.md          # Verified session-log facts + design decisions
├── data-model.md        # Types, state machines, invariants
├── quickstart.md        # Manual verification via drop-box events
├── contracts/
│   └── agent-event-contract.md   # Drop-box / adapter event contract v2
└── tasks.md             # Generated by /spec-kitty.tasks
```

### Source Code (repository root)

```
src/
├── Models/
│   ├── AgentModels.swift              # + almostDone/warning/usage kinds, metadata, AgentSignalSettings, AgentWarning, AgentContextReading
│   └── TelemetryModels.swift          # AgentTelemetry + context reading text
├── Services/
│   ├── AgentMonitorService.swift      # policy: usage, context crossing, stall sweep, warning slot, settings (injected defaults)
│   ├── SessionLogTail.swift           # NEW shared incremental reader (offsets, partial lines, truncation, 256 KB seed)
│   ├── AgentSessionTracker.swift      # NEW pure tracker (turn state, pending tools, loop streak, latest tokens)
│   ├── ClaudeCodeTranscriptAdapter.swift  # NEW Claude Code session-log adapter
│   ├── AntigravityTranscriptAdapter.swift # usage/loop/pending via shared tail + tracker
│   └── TelemetryDashboardService.swift    # pass context reading into AgentTelemetry
├── Views/
│   ├── SpeechBubbleView.swift         # warning bubble with GOT IT, almost-done style, isInteractive
│   ├── MascotOverlayView.swift        # amber visor override
│   └── Settings/AgentsSettingsTabView.swift  # signals & thresholds card
└── App/BitzApp.swift                  # wire Claude adapter; pass agentMonitor to MascotOverlayView
docs/
├── agent-dropbox-event.schema.json    # new kinds + metadata
├── ARCHITECTURE.md, STATE_MACHINE.md, ACCEPTANCE_CRITERIA.md
Tests/BitzTests/
├── AgentMonitorServiceTests.swift     # lifecycle for almostDone / warning / usage
├── AgentSignalPolicyTests.swift       # NEW context crossing, stall sweep, slot priority, settings persistence
├── SessionLogTailTests.swift          # NEW incremental reads, partial lines, truncation, seed cap
├── AgentSessionTrackerTests.swift     # NEW loop streak, pending tools, turn boundaries
├── ClaudeCodeTranscriptAdapterTests.swift  # NEW fixture replays (subagent skip, sidechain skip, seed)
├── AntigravityTranscriptAdapterTests.swift # usage + loop fixtures
├── DropboxAgentAdapterTests.swift     # decode new kinds + metadata, old payloads unchanged
├── MascotOverlayLayoutTests.swift, SpeechBubblePanelTests.swift, OverlayTestFixtures.swift
├── TelemetryDashboardServiceTests.swift, SettingsViewsTests.swift, SettingsIntegrationTests.swift
```

**Structure Decision**: Existing single-package layout; new files sit beside their peers (`Services/` for adapters and helpers). No new targets.

## Complexity Tracking

| Deviation | Why needed | Simpler alternative rejected because |
|-----------|------------|--------------------------------------|
| Seventh event kind `usage` beyond the six kinds named in the spec's Key Entities | Context readings and activity heartbeats must reach the monitor without showing a bubble | Overloading `working` with metadata would trigger "is working…" popups on every poll; a second adapter callback would change the `AgentAdapter` protocol and every mock. Spec Key Entities amended in the same commit. |
| `MascotOverlayView` gains an `agentMonitor` parameter (3 call sites) | Visor must react to the warning slot | Routing the flag through `WellnessPointEngine` would mix agent policy into wellness state (DIRECTIVE_001). |

## Implementation Concern Map

### IC-01 — Event Model & Drop-box Contract
- **Purpose**: Extend the event vocabulary (`almostDone`, `warning`, `usage`), add optional `metadata`, keep old drop-box payloads decoding unchanged, publish the v2 contract.
- **Relevant requirements**: FR-001, FR-002, FR-003, C-001
- **Affected surfaces**: `src/Models/AgentModels.swift`, `docs/agent-dropbox-event.schema.json`, `Tests/BitzTests/DropboxAgentAdapterTests.swift`
- **Sequencing/depends-on**: none
- **Risks**: exhaustive `switch` on `AgentEventKind` in `AgentMonitorService` and `SpeechBubbleView` must be updated in the same change to keep the build green.

### IC-02 — Monitor Policy & Signal Settings
- **Purpose**: Context readings and threshold crossing per agent, stall sweep, single warning slot with approval override and restoration, acknowledgement, toggles, disabled-agent clearing, quiet seeding, settings persistence via injected defaults.
- **Relevant requirements**: FR-001, FR-002, FR-005, FR-007, FR-009, FR-010, FR-012 (model), FR-013, FR-014, NFR-003, NFR-005
- **Affected surfaces**: `src/Services/AgentMonitorService.swift`, `src/Models/AgentModels.swift` (settings/value types), `Tests/BitzTests/AgentMonitorServiceTests.swift`, `Tests/BitzTests/AgentSignalPolicyTests.swift`
- **Sequencing/depends-on**: IC-01
- **Risks**: popup-priority regressions for existing working/needsApproval/done behaviour; existing tests write `UserDefaults.standard` — keep them working while new tests use isolated suites.

### IC-03 — Session-Log Reading (Claude Code + Antigravity)
- **Purpose**: Shared incremental tail reader, pure session tracker (turns, pending tools, loop streak, latest tokens), new Claude Code adapter (top-level sessions only, sidechain lines skipped), Antigravity adapter emitting usage/loop/pending.
- **Relevant requirements**: FR-004, FR-005, FR-008, FR-009 (activity + pending inputs), FR-014, NFR-001, NFR-002, NFR-004, NFR-006, C-003
- **Affected surfaces**: `src/Services/SessionLogTail.swift`, `src/Services/AgentSessionTracker.swift`, `src/Services/ClaudeCodeTranscriptAdapter.swift`, `src/Services/AntigravityTranscriptAdapter.swift`, matching tests
- **Sequencing/depends-on**: IC-01
- **Risks**: undocumented, evolving session-log formats (mitigated: skip unknown lines, fixtures from verified structure); `AntigravityTranscriptAdapter` also receives the separate #63 fix — keep edits local to avoid conflicts.

### IC-04 — Mascot Presentation (Bubble, Visor, Gauge)
- **Purpose**: Interactive warning bubble with **Got it**, distinct almost-done bubble, amber visor override, context text on the AI Agents metric, app wiring (Claude adapter, `agentMonitor` into `MascotOverlayView`).
- **Relevant requirements**: FR-006, FR-010 (presentation), FR-011, C-002, C-005
- **Affected surfaces**: `src/Views/SpeechBubbleView.swift`, `src/Views/MascotOverlayView.swift`, `src/App/BitzApp.swift`, `src/Models/TelemetryModels.swift`, `src/Services/TelemetryDashboardService.swift`, `Tests/BitzTests/MascotOverlayLayoutTests.swift`, `Tests/BitzTests/SpeechBubblePanelTests.swift`, `Tests/BitzTests/OverlayTestFixtures.swift`, `Tests/BitzTests/SettingsIntegrationTests.swift`, `Tests/BitzTests/TelemetryDashboardServiceTests.swift`
- **Sequencing/depends-on**: IC-02, IC-03
- **Risks**: warning bubble with button must stay inside its window at every scale (layout test); click-through must revert immediately after **Got it**.

### IC-05 — Signal Settings UI
- **Purpose**: AI Agents tab card: per-signal toggles, context threshold (50–99%), stall timeout (1–30 min), per-agent context window (200k / 1M / custom).
- **Relevant requirements**: FR-012, SC-005
- **Affected surfaces**: `src/Views/Settings/AgentsSettingsTabView.swift`, `Tests/BitzTests/SettingsViewsTests.swift`
- **Sequencing/depends-on**: IC-02
- **Risks**: custom window input validation (positive integers only).

### IC-06 — Living Docs & Verification
- **Purpose**: Sync living docs (DIR-005), run the full suite, package and run the release build, manual quickstart pass, Activity Monitor resource check.
- **Relevant requirements**: SC-001…SC-006, NFR-001, C-005
- **Affected surfaces**: `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, `docs/ACCEPTANCE_CRITERIA.md`
- **Sequencing/depends-on**: IC-01…IC-05
- **Risks**: none beyond flaky UI layout timing on CI (existing `spinRunLoop` helper).
