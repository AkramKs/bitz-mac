---
work_package_id: WP06
title: Warning Bubble, Amber Visor & App Wiring
dependencies:
- WP02
- WP04
requirement_refs:
- C-002
- C-005
- C-006
- FR-001
- FR-010
- FR-011
planning_base_branch: feat/issue-38-agent-gauges-warnings
merge_target_branch: feat/issue-38-agent-gauges-warnings
branch_strategy: Planning artifacts for this mission were generated on feat/issue-38-agent-gauges-warnings. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into feat/issue-38-agent-gauges-warnings unless the human explicitly redirects the landing branch.
subtasks:
- T026
- T027
- T028
- T029
- T030
- T031
phase: Phase 3 - Presentation
history:
- !!omap
  - at: '2026-10-30T13:37:15Z'
  - actor: system
  - action: Prompt generated via /spec-kitty.tasks
agent_profile: implementer-ivan
authoritative_surface: src/Views/
create_intent:
- Tests/BitzTests/AgentWarningPresentationTests.swift
execution_mode: code_change
model: ''
owned_files:
- src/Views/SpeechBubbleView.swift
- src/Views/MascotOverlayView.swift
- src/App/BitzApp.swift
- Tests/BitzTests/OverlayTestFixtures.swift
- Tests/BitzTests/MascotOverlayLayoutTests.swift
- Tests/BitzTests/SpeechBubblePanelTests.swift
- Tests/BitzTests/AgentWarningPresentationTests.swift
role: implementer
tags: []
task_type: implement
tracker_refs: []
---

# Work Package Prompt: WP06 – Warning Bubble, Amber Visor & App Wiring

## ⚡ Do This First: Load Agent Profile

Use the `/ad-hoc-profile-load` skill to load the agent profile specified in the frontmatter, and behave according to its guidance before parsing the rest of this prompt.

- **Profile**: `implementer-ivan`
- **Role**: `implementer`
- **Agent/tool**: `claude`

If no profile is specified, run `spec-kitty agent profile list` and select the best match for this work package's `task_type` and `authoritative_surface`.

---

## ⚠️ IMPORTANT: Review Feedback

- **Has review feedback?**: Check the `review_ref` field in the event log or the Activity Log below.
- **You must address all feedback** before your work is complete.

---

## Objectives & Success Criteria

Present the WP02 policy on the mascot and wire the new adapter (FR-001, FR-010, FR-011, C-002, C-005). Done when:
- A `.warning` agent popup renders a distinct warning bubble with a **GOT IT** button that calls `agentMonitor.acknowledgeWarning()`; only this bubble (and the existing update bubble) takes clicks.
- A `.almostDone` popup renders a distinct eager style (no button, click-through).
- The visor is Amber `#FFB000` while `agentMonitor.activeWarning != nil`, except when the wellness state is `.overheating` (red wins).
- The app runs `ClaudeCodeTranscriptAdapter` alongside the existing adapters and creates `AgentMonitorService` with the delegate's injected `userDefaults`.
- Layout tests prove both new bubbles fit their window at the largest scale; the click-through test proves the bubble reverts to `ignoresMouseEvents = true` right after **GOT IT**.

## Context & Constraints

- AGENTS.md §2.1/§2.2/§2.4: panels never become key; bubble panel takes clicks only while an interactive bubble shows; nothing drawn outside its window (`MascotOverlayLayoutTests`).
- Existing interactivity path: `SpeechBubbleContent.isInteractive` (`src/Views/SpeechBubbleView.swift:12-17`) → `BitzAppDelegate.updatePanelsInteractivity()` (`src/App/BitzApp.swift:221-234`), re-run on every `activePopup` change by `bubbleInteractivityCancellable` (`BitzApp.swift:111-119`). Reuse it; add nothing parallel.
- WP01 left placeholder colours for the new kinds in `agentPopupColors`; replace them.
- This WP stacks on PR #62's bubble window (C-006); do not touch `SpeechBubblePanel.swift`.

## Branch Strategy

- **Planning base branch**: `feat/issue-38-agent-gauges-warnings`
- **Merge target branch**: `feat/issue-38-agent-gauges-warnings`
- Execution worktrees are allocated per computed lane from `lanes.json`.
- Implementation command: `spec-kitty agent action implement WP06 --agent claude`

## Subtasks & Detailed Guidance

### Subtask T026 – Warning + almost-done bubbles, interactivity

- **File**: `src/Views/SpeechBubbleView.swift`
- **Steps**:
  1. `SpeechBubbleContent.isInteractive`: return `true` for `.update` **and** for `.agentPopup(p)` where `p.kind == .warning`. Update the doc comment ("Update alert and agent warning bubbles have buttons…").
  2. In `bubble`, for `.agentPopup(let popup)`: if `popup.kind == .warning` → `warningBubbleView(popup)`; else existing `textBubble`.
  3. `warningBubbleView`: mirror `updateBubbleView` structure — `VStack(spacing: 5)` with the text (same font/lineLimit/minimumScaleFactor as `textBubble`) and one capsule button `GOT IT` (black text on amber capsule) calling `agentMonitor.acknowledgeWarning()`; stroke Amber `#FFB000`, fill `Color(red: 0.45, green: 0.12, blue: 0.04).opacity(0.96)`; `.frame(maxWidth: Self.maxBubbleWidth)`; shadow like the others.
  4. `agentPopupColors`: `.almostDone` → stroke Magenta `#FF007F`, fill `Color(red: 0.42, green: 0.10, blue: 0.55).opacity(0.96)`; `.warning` → the warning pair above (used if ever rendered as text); `.usage` → existing cyan pair (never shown).
- **Notes**: Keep the priority order in `SpeechBubbleContent.current` unchanged (agent popup first).

### Subtask T027 – Amber visor override [P]

- **File**: `src/Views/MascotOverlayView.swift`
- **Steps**:
  1. Add `@ObservedObject public var agentMonitor: AgentMonitorService` and init parameter `agentMonitor: AgentMonitorService = AgentMonitorService()` placed after `telemetrySettings` (matches the defaulted-store pattern; existing call sites in `SettingsIntegrationTests` keep compiling).
  2. Add:
     ```swift
     /// Agent warnings turn the visor amber; overheating red keeps priority (FR-011).
     public static func visorRGB(for state: BitzState, agentWarningActive: Bool) -> (red: Double, green: Double, blue: Double) {
         agentWarningActive && state != .overheating ? visorRGB(for: .overworked) : visorRGB(for: state)
     }
     public static func visorColor(for state: BitzState, agentWarningActive: Bool) -> Color
     ```
     Keep the existing one-argument functions untouched (used by `SpeechBubbleView`, `MascotOverlayPanelTests`, `SettingsViewsTests`).
  3. Private `visorColor` → `Self.visorColor(for: engine.currentState, agentWarningActive: agentMonitor.activeWarning != nil)`.
- **Notes**: Engine state and Rive inputs are untouched (charter DIR-004).

### Subtask T028 – App wiring

- **File**: `src/App/BitzApp.swift`
- **Steps**:
  1. Next to the existing adapters (`BitzApp.swift:71-75`): `let claudeAdapter = ClaudeCodeTranscriptAdapter()` and include it in the adapters array.
  2. `AgentMonitorService(adapters: [...], userDefaults: userDefaults)` — the delegate's injected defaults (NFR-005; tests already pass isolated defaults into the delegate).
  3. `createConfiguredPanel()` → pass `agentMonitor: agentMonitor` to `MascotOverlayView(...)`.
  4. Leave `bubbleInteractivityCancellable` as is (it already reacts to `$activePopup`).

### Subtask T029 – Fixtures + layout tests

- **Files**: `Tests/BitzTests/OverlayTestFixtures.swift`, `Tests/BitzTests/MascotOverlayLayoutTests.swift`
- **Steps**:
  1. `OverlayFixture`: construct `agentMonitor` with the fixture's isolated `defaults` if it isn't already; pass it to `mascotView(...)`; add helpers:
     ```swift
     func showWarning(_ text: String) { agentMonitor.handleEvent(AgentEvent(agentID: "claude", agentName: "Claude", kind: .warning, message: text, metadata: [AgentEvent.MetadataKey.reason: "reported"])) }
     func showAlmostDone(_ text: String) { agentMonitor.handleEvent(AgentEvent(agentID: "claude", agentName: "Claude", kind: .almostDone, message: text)) }
     ```
  2. Layout tests (mirror `testUpdateBubbleAtLargestScaleIsNotClippedByItsWindow`):
     - `testWarningBubbleWithButtonAtLargestScaleIsNotClippedByItsWindow` (long text, max scale).
     - `testAlmostDoneBubbleIsNotClippedByItsWindow`.
     - `testMascotWithAgentWarningStaysInsidePanel` (visor change must not affect bounds).

### Subtask T030 – Click-through test

- **File**: `Tests/BitzTests/SpeechBubblePanelTests.swift`
- Add `testWarningBubbleTakesClicksOnlyUntilAcknowledged` modelled on `testOnlyABubbleWithButtonsTakesClicks` (synchronous, same comment about main-queue callbacks):
  1. Delegate with isolated defaults; `setupOverlayPanel()`.
  2. `handleEvent(.warning …)` → `spinRunLoop { !bubble.ignoresMouseEvents }`; mascot panel still click-through.
  3. `agentMonitor.acknowledgeWarning()` → `spinRunLoop { bubble.ignoresMouseEvents }`.
  4. `handleEvent(.almostDone …)` → bubble stays click-through.
  5. Assert `bubble.canBecomeKey == false` throughout (AGENTS.md §2.2).

### Subtask T031 – Presentation unit tests

- **File**: `Tests/BitzTests/AgentWarningPresentationTests.swift` (new, `@MainActor`)
- Cases:
  1. `testVisorAmberWhileWarningActiveForEveryStateExceptOverheating` — loop over `BitzState` cases.
  2. `testVisorUnchangedWithoutWarning`.
  3. `testOnlyWarningAgentPopupIsInteractive` — `SpeechBubbleContent.agentPopup` for each `AgentEventKind` (only `.warning` true); `.update` still true.
  4. `testMascotViewReflectsMonitorWarning` — build `MascotOverlayView` with a monitor, raise/acknowledge a warning, evaluate `body` without crashing (smoke, like `SettingsViewsTests`).

## Test Strategy

- Run `xcrun swift test --filter MascotOverlayLayoutTests`, `--filter SpeechBubblePanelTests`, `--filter AgentWarningPresentationTests`, `--filter MascotOverlayPanelTests`, then the full suite. Isolated defaults everywhere (AGENTS.md §3.2).

## Risks & Mitigations

- **Interactive bubble left on**: covered by T030 step 3.
- **Default `AgentMonitorService()` in the view initializer** reads `UserDefaults.standard` in tests that don't pass a monitor; harmless (read-only) and consistent with the other defaulted stores.

## Review Guidance

- Verify only `SpeechBubbleView.swift`'s `isInteractive` changed for interactivity; no new click-handling path.
- Verify `MascotOverlayPanel` code is untouched.
- Compare bubble styles visually via `./Scripts/package_and_run.sh release` + `quickstart.md` §1 if possible.

## Activity Log

- 2026-10-30T13:37:15Z – system – Prompt created.
