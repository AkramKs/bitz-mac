## Summary
Bitz should detect when an AI coding agent (Gemini, Claude, Antigravity/"Agy", etc.) is working and show a popup bubble when the agent finishes or needs approval.

## Environment
- **Product/Service**: bitz-mac (Bitz the Cyber Cat)
- **Region/Version**: current `main`
- **Browser/OS**: macOS 14.0+ (Apple Silicon)

## Reproduction Steps
1. Launch Bitz.
2. Run an AI agent (Gemini CLI/app, Claude Code/Desktop, Antigravity) on a long task.
3. Switch to another app while it works.
4. Wait for the agent to finish or to request approval (tool/command permission).

## Expected Behavior
- Bitz notices an agent is running, whichever tool it is, and shows a working state.
- A speech-bubble popup appears when the agent is **done** or **waiting for approval**, even if the agent's window is in the background.
- Detection works for Gemini, Claude, Antigravity and is extensible to other agents (Cursor, Codex, etc.).

## Actual Behavior
Bitz only treats these apps as "productive" for PTS purposes (bundle IDs and name keywords in [ActivityMonitorService.swift](src/Services/ActivityMonitorService.swift)). It has no concept of agent activity, completion, or approval requests, and shows no popups.

## Feasibility (answer to "is this possible?")
**Yes, with tiers of reliability:**
1. **Process detection (easy, reliable)**: poll running processes (`NSWorkspace.runningApplications`, `proc_listpids`/`ps`) for `claude`, `gemini`, `agy`/`antigravity` and track CPU activity or child processes. This shows "agent running". It cannot tell "done" vs "waiting" reliably on its own.
2. **Hooks / log files (best for done + approval)**:
   - Claude Code supports hooks (`Notification`, `Stop`) in `~/.claude/settings.json`. These fire on "needs permission" and "finished". A hook could write to a file or post to a local socket/`DistributedNotificationCenter` that Bitz listens to.
   - Gemini CLI: session logs/telemetry under `~/.gemini/`; hooks may be available depending on version (needs verification).
   - Antigravity: watch its app data dir (`~/.gemini/antigravity/`) for state/log changes (needs investigation).
   - Bitz would watch these via `FSEvents`/`DispatchSource`, with no Accessibility permission required.
3. **Terminal output / UI scraping (fragile, last resort)**: needs Accessibility or screen capture permissions. This conflicts with the project's zero-permission privacy stance. Not recommended.

## Supported Agents (target: all most-used agents, not just Gemini)
| Agent | Type | Detection (primary) | Fallback |
| :--- | :--- | :--- | :--- |
| Claude Code / Claude Desktop | CLI / app | Hooks (`Notification`, `Stop`) | Process `claude`, `com.anthropic.claudefordesktop` |
| Gemini CLI / Gemini app | CLI / app | Logs/hooks under `~/.gemini/` (spike) | Process `gemini`, `com.google.GeminiMacOS` |
| Antigravity (Agy) | IDE | State/logs in `~/.gemini/antigravity/` (spike) | Process `agy`/`antigravity` |
| OpenAI Codex CLI / ChatGPT app | CLI / app | `notify` config hook in `~/.codex/config.toml` | Process `codex`, ChatGPT bundle ID |
| Cursor (agent mode) | IDE | Log/state watching (spike) | Bundle ID `com.todesktop.*` |
| Windsurf (Cascade) | IDE | Log/state watching (spike) | Process/bundle ID |
| GitHub Copilot (VS Code agent) | IDE extension | VS Code log watching (spike) | Process `Code` |
| Aider, Goose, OpenCode, Amp, Cline/Roo | CLI / extension | Process + terminal/log watching | Process name |

Any agent not listed must be addable through a user-defined entry (process name or bundle ID, plus an optional log path or hook command), so Bitz is not limited to a hard-coded list.

## Proposed Approach
- Add an `AgentMonitorService` with pluggable per-agent adapters (`ProcessAdapter`, `HookAdapter`, `LogWatcherAdapter`).
- Define a unified event model: `agentStarted`, `agentWorking`, `agentNeedsApproval`, `agentDone`.
- Add a local event channel (file in `~/Library/Application Support/Bitz/events/` or a Unix socket), plus a menu-bar "Install Claude hook" helper.
- Add a popup speech bubble to [MascotOverlayView.swift](src/Views/MascotOverlayView.swift) with distinct states (working / approval needed / done), auto-dismiss, and optional sound.
- Overlay is click-through, so popups must be non-interactive; clicking is not possible.
- Menu-bar toggles per agent; update README.

## Acceptance Criteria
- [ ] Bitz shows a working state when any supported agent (Claude, Gemini, Antigravity, Codex, Cursor, Windsurf, Copilot, Aider, etc.) is running a task.
- [ ] Users can register custom agents (process name / bundle ID / log path).
- [ ] Popup text appears on "done" and on "needs approval".
- [ ] No Accessibility or keylogging permissions added.
- [ ] Per-agent enable/disable in the menu bar.
- [ ] Adding a new agent needs only a new adapter.

## Impact
**Medium**: new feature, no workaround. Core value for users who run agents in the background.

## Additional Context
Open questions: exact hook/log mechanisms for Gemini CLI and Antigravity need a spike before committing to "approval" detection for those. The process-only fallback may only support "running/stopped".
