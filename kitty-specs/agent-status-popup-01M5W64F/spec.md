# Mission Specification: AI Agent Status Detection & Popup

**Mission Branch**: `feat/agent-status-popup`  
**Created**: 2026-10-26  
**Status**: Draft  
**Input**: User description: "The mascot should also notice an AI agent working (Gemini, Claude, Agy, Codex, Cursor and other most-used agents) no matter what, and give a popup text telling the agent is done or asks for an approval." (GitHub issue #1)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Notice a running agent (Priority: P1)

While an AI agent (Claude, Gemini, Antigravity, Codex, Cursor, etc.) works on a task, Bitz visibly shows a "agent working" state, even when the agent's window is in the background.

**Why this priority**: Foundation for all other behavior; works with process detection alone and needs no per-agent integration.

**Independent Test**: Start a supported agent CLI/app, switch to another app; Bitz enters the working state within the detection interval and leaves it after the agent exits.

**Acceptance Scenarios**:

1. **Given** Bitz is running, **When** a supported agent process starts, **Then** Bitz shows the working state.
2. **Given** the working state is shown, **When** the agent process exits, **Then** the working state clears.
3. **Given** several agents run at once, **When** any is active, **Then** Bitz shows the working state and names the agent(s).

---

### User Story 2 - Popup when agent is done (Priority: P1)

When an agent finishes a task, Bitz displays a speech-bubble popup such as "Claude is done".

**Why this priority**: Core user value: no need to watch the agent.

**Independent Test**: Run a short Claude Code task with the hook installed; a "done" popup appears on completion and auto-dismisses.

**Acceptance Scenarios**:

1. **Given** an agent with a hook/log adapter, **When** it signals completion, **Then** a "done" popup naming the agent appears and auto-dismisses.
2. **Given** an agent with only process detection, **When** its process exits, **Then** a generic "finished" popup appears.

---

### User Story 3 - Popup when agent needs approval (Priority: P1)

When an agent asks for permission (run command, edit file), Bitz shows a distinct "needs approval" popup that persists until the agent resumes or the user acts.

**Why this priority**: This is when the agent is blocked; most time-sensitive notification.

**Independent Test**: Trigger a Claude Code permission prompt; the approval popup appears within 2 seconds.

**Acceptance Scenarios**:

1. **Given** an agent with approval signaling, **When** it requests approval, **Then** an "approval needed" popup appears, visually distinct from "done".
2. **Given** the approval popup is shown, **When** the agent resumes, **Then** the popup clears.

---

### User Story 4 - Broad and extensible agent support (Priority: P2)

Most-used agents are supported out of the box, and users can add custom agents.

**Why this priority**: The user wants it to work with all agents, not only Gemini.

**Independent Test**: Add a custom agent (process name) in the menu bar; Bitz detects it.

**Acceptance Scenarios**:

1. **Given** a built-in agent list (Claude Code/Desktop, Gemini CLI/app, Antigravity, Codex/ChatGPT, Cursor, Windsurf, Copilot, Aider, Goose, OpenCode, Amp, Cline), **When** any runs, **Then** it is detected.
2. **Given** a user-defined agent (process name or bundle ID, optional log path/hook), **When** it runs, **Then** it is detected and handled like built-ins.

---

### User Story 5 - Control and setup (Priority: P3)

Users can enable/disable each agent and popups, and install Claude/Codex hooks from the menu bar.

**Why this priority**: Polish and control; core works without it.

**Independent Test**: Disable an agent in the menu; no state or popup appears for it.

**Acceptance Scenarios**:

1. **Given** an agent is disabled, **When** it runs, **Then** Bitz ignores it.
2. **Given** the user chooses "Install hook", **When** confirmed, **Then** the hook config is added reversibly and clearly reported.

---

### Edge Cases

- Agent crashes or is killed mid-task: working state must clear; no stuck approval popup.
- Multiple agents emit events concurrently: popups queue or stack without overlap.
- Hook installed but Bitz not running: events are dropped or expire (stale events ignored).
- Agent process is idle (open but not working): must not count as "working" (use CPU/child-process activity heuristic).
- Overlay is click-through: popups are display-only.
- Agent has no hook/log support: degrades to running/stopped only, and says so.
- Full-screen apps and multiple Spaces: popup still visible.

## Requirements *(mandatory)*

### Functional Requirements

| ID | Title | User Story | Priority | Status |
|----|-------|------------|----------|--------|
| FR-001 | Agent process detection | As a user, I want Bitz to notice any supported agent running so that I know it is working. | High | Open |
| FR-002 | Unified agent event model | As a developer, I want events `started`, `working`, `needsApproval`, `done` so that all agents map to one model. | High | Open |
| FR-003 | Done popup | As a user, I want a popup when an agent finishes so that I need not watch it. | High | Open |
| FR-004 | Approval popup | As a user, I want a distinct popup when an agent needs approval so that I can unblock it. | High | Open |
| FR-005 | Claude Code hook adapter | As a Claude Code user, I want hook-based done/approval signals so that detection is accurate. | High | Open |
| FR-006 | Hook/log adapters for other agents | As a user of Gemini, Antigravity, Codex, Cursor, Windsurf, Copilot, etc., I want accurate signals where the agent exposes them. | Medium | Open |
| FR-007 | Custom agents | As a user, I want to register my own agent so that unlisted tools work. | Medium | Open |
| FR-008 | Per-agent toggles | As a user, I want to enable/disable agents and popups from the menu bar. | Low | Open |
| FR-009 | Hook installer | As a user, I want one-click, reversible hook installation. | Low | Open |
| FR-010 | Graceful degradation | As a user, I want running/stopped detection even when an agent exposes no signals. | Medium | Open |

### Non-Functional Requirements

| ID | Title | Requirement | Category | Priority | Status |
|----|-------|-------------|----------|----------|--------|
| NFR-001 | Detection latency | Hook events shown within 2 s; process changes within 5 s | Performance | High | Open |
| NFR-002 | CPU overhead | Added monitoring stays under 1% average CPU | Performance | High | Open |
| NFR-003 | Privacy | No Accessibility, screen-capture or keystroke permissions; no agent content read or transmitted | Security | High | Open |
| NFR-004 | Stale events | Events older than 60 s are discarded | Reliability | Medium | Open |
| NFR-005 | Extensibility | Adding a built-in agent requires only a new adapter/config entry, no changes to UI code | Maintainability | Medium | Open |

### Constraints

| ID | Title | Constraint | Category | Priority | Status |
|----|-------|------------|----------|----------|--------|
| C-001 | Click-through overlay | Popups must not accept mouse input or take focus (`MascotOverlayPanel` stays non-activating) | Technical | High | Open |
| C-002 | Platform | macOS 14+ Apple Silicon, Swift/SwiftUI/AppKit only | Technical | High | Open |
| C-003 | No scraping | UI/terminal scraping requiring Accessibility is out of scope | Technical | High | Open |
| C-004 | Spike dependency | Gemini CLI, Antigravity, Cursor, Windsurf and Copilot signal mechanisms must be verified before promising approval detection | Technical | Medium | Open |

### Key Entities *(include if feature involves data)*

- **Agent Definition**: Name, process names/bundle IDs, optional hook or log path, enabled flag; built-in or user-defined.
- **Agent Event**: Agent id, type (started/working/needsApproval/done), timestamp, optional message.
- **Popup**: Text, kind (working/approval/done), lifetime, source agent.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Claude Code "done" and "approval needed" popups appear within 2 s of the hook firing, in 100% of manual test runs.
- **SC-002**: At least 8 of the listed agents are detected as running (process level).
- **SC-003**: A user can add a custom agent and see it detected in under 1 minute.
- **SC-004**: Monitoring adds under 1% average CPU and requests no new macOS permissions.
