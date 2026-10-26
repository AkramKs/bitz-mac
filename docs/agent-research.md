# Spike Research Report: Agent Signaling Mechanisms (S1–S4)

This report documents the signaling capabilities and local filesystem / process signatures for popular AI coding agents on macOS.

## Summary of Findings

| Agent | Signal Channel | Supported States | Status |
| :--- | :--- | :--- | :--- |
| **Claude Code** | Hooks in `~/.claude/settings.json` (`Stop`, `Notification`) | `.started`, `.working`, `.needsApproval`, `.done` | Direct drop-box hook supported |
| **Antigravity (Agy)** | Workspace transcript logs in `<appDataDir>/brain/<id>/...` | `.working`, `.needsApproval` (WAITING_USER_INPUT), `.done` | Log watcher adapter supported |
| **Codex CLI / ChatGPT** | Config notify hook in `~/.codex/config.toml` | `.started`, `.done` | Drop-box hook supported |
| **Gemini CLI** | Process execution & session telemetry | `.started`, `.working` (CPU > 1%), `.done` | Baseline process adapter (fallback) |
| **Cursor** | Editor state logs in `~/Library/Application Support/Cursor` | `.started`, `.working`, `.done` | Process adapter + Log watcher |
| **Windsurf / Copilot** | IDE processes & telemetry | `.started`, `.working`, `.done` | Process adapter (baseline) |

## Spike Details

### S1: Gemini CLI
- Primarily logs via standard CLI streams and local telemetry cache. No stable public hook mechanism for arbitrary pre-approval traps.
- **Decision**: Uses `ProcessAgentAdapter` baseline.

### S2: Antigravity IDE (Agy)
- Writes session execution events to disk. User input / tool confirmation checkpoints emit status markers (`WAITING_USER_INPUT` / `needsApproval`).
- **Decision**: `LogWatcherAgentAdapter` monitors configured log directories for structured state transitions.

### S3: OpenAI Codex CLI
- Supports notification hook command execution on task completion.
- **Decision**: Can drop event JSONs to `~/Library/Application Support/Bitz/agent-events/` identically to Claude Code.

### S4: Cursor / Windsurf / Copilot
- Electron/VSCode-based IDE agents have internal state engines that do not expose unauthenticated public unix sockets.
- **Decision**: Process-level detection (`ProcessAgentAdapter`) provides zero-permission tracking without violating sandboxing or requiring Accessibility permissions.
