# Spike Research Report: Agent Signaling Mechanisms (S1–S4)

This report documents the signaling capabilities and local filesystem / process signatures for popular AI coding agents on macOS.

## Summary of Findings

| Agent | Signal Channel | Supported States | Status |
| :--- | :--- | :--- | :--- |
| **Claude Code** | Hooks in `~/.claude/settings.json` (`Stop`, `PermissionRequest`, `Notification`) | `.started`, `.working`, `.needsApproval`, `.done` | Implemented via `DropboxAgentAdapter` + `AgentHookInstaller` |
| **Antigravity (Agy)** | Workspace transcript logs in `~/.gemini/antigravity/brain/*/transcript.jsonl` | `.working`, `.needsApproval` (`ask_question`), `.done` | Implemented via `AntigravityTranscriptAdapter` |
| **Codex CLI / ChatGPT** | Config notify hook in `~/.codex/config.toml` | `.started`, `.done` | Drop-box hook supported |
| **Gemini CLI** | Process execution & session telemetry | `.started`, `.working` (CPU > 1%), `.done` | Baseline process adapter (fallback) |
| **Cursor** | Editor state logs in `~/Library/Application Support/Cursor` | `.started`, `.working`, `.done` | Process adapter + Log watcher |
| **Windsurf / Copilot** | IDE processes & telemetry | `.started`, `.working`, `.done` | Process adapter (baseline) |

## Spike Details

### S1: Gemini CLI
- Primarily logs via standard CLI streams and local telemetry cache. No stable public hook mechanism for arbitrary pre-approval traps.
- **Decision**: Uses `ProcessAgentAdapter` baseline.

### S2: Antigravity IDE (Agy)
- Writes real-time session execution events to `~/.gemini/antigravity/brain/<conversation-id>/.system_generated/logs/transcript.jsonl`.
- `USER_INPUT` triggers `.working` ("Antigravity is working...").
- Tool calls invoking `ask_question` trigger `.needsApproval` ("Antigravity needs input!").
- Terminal `PLANNER_RESPONSE` events with `status: "DONE"` and empty `tool_calls` trigger `.done` ("Antigravity is done!").
- **Decision**: Implemented via `AntigravityTranscriptAdapter`, which dynamically tracks the active session directory and streams incremental transcript line updates without requiring special permissions.

### S3: OpenAI Codex CLI
- Supports notification hook command execution on task completion.
- **Decision**: Can drop event JSONs to `~/Library/Application Support/Bitz/agent-events/` identically to Claude Code.

### S4: Cursor / Windsurf / Copilot
- Electron/VSCode-based IDE agents have internal state engines that do not expose unauthenticated public unix sockets.
- **Decision**: Process-level detection (`ProcessAgentAdapter`) provides zero-permission tracking without violating sandboxing or requiring Accessibility permissions.
