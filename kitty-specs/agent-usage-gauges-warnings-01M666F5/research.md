# Research: Agent Usage Gauges, "Almost Done" Milestones & Critical Warnings

All transcript facts below come from structure-only scans (keys, types, tool names, counts) of local session logs on 2026-10-30. No message text was read or recorded.

## Verified session-log facts

| Fact | Evidence |
|------|----------|
| Claude Code assistant lines carry `message.usage` with `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens`, and `message.model` | Newest session schema scan |
| Claude Code context (input + cache creation + cache read) reaches ~943k tokens; model strings carry no window marker | Max over 40 recent sessions |
| Claude Code subagent sessions live in nested files (325 nested vs 69 top-level); top-level files contain 0 sidechain lines | Glob counts + `isSidechain` scan |
| Claude Code turn boundaries: `stop_reason` `end_turn` (727) vs `tool_use` (10,334); system subtypes `turn_duration` (487), `stop_hook_summary` (490), `compact_boundary` (17), `local_command` (7) | 40 recent top-level sessions |
| Interrupted turns carry a user text marker starting `[Request interrupted` (5 occurrences) | Prefix match only |
| No `TodoWrite` tool use in Claude Code sessions here | 0 of all tool_use blocks |
| Antigravity lines carry `input_tokens`, `cache_read_tokens`, `output_tokens`, `step_index`; tool calls are `{name, args}` (5,656) or `{name}` (2), never `{function}` | 70 transcripts |
| Antigravity `ask_question` appears 19× but the current adapter checks `function.name` | Tracked separately as #63 |

## Decisions

### R1 — Policy placement
- **Decision**: `AgentMonitorService` owns thresholds, stall timer, warning slot, acknowledgement and toggles; adapters only parse (decision `policy_placement`, resolved by user).
- **Rationale**: one MainActor owner for settings (no cross-thread settings box), policy testable with synthetic events and an injected clock, drop-box integrators get context and stall support without code.
- **Alternatives considered**: adapters detect warnings themselves (needs a thread-safe settings snapshot per adapter; duplicates stall/context logic per agent).

### R2 — Carrying readings: new `usage` kind
- **Decision**: add `AgentEventKind.usage` (never shown) with metadata `contextTokens`, `pendingTools`, `turnActive`, `seed`.
- **Rationale**: readings and activity heartbeats must not trigger popups; the `AgentAdapter` protocol and mocks stay unchanged.
- **Alternatives considered**: metadata on `working` (spams "is working…" bubbles); a second adapter callback (protocol + every mock change).

### R3 — Context measure and window
- **Decision**: Claude Code = `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` of the latest top-level assistant line; Antigravity = `input_tokens + cache_read_tokens` of the latest line carrying tokens. Window per agent from settings (Claude Code 200k, Antigravity 1M, others 200k); percent capped at 100; raw tokens always shown.
- **Rationale**: input side of the latest turn is what occupies the window; output tokens join the next turn's input.
- **Alternatives considered**: infer window from model name (no marker in logs); single global window (shows 470% for 1M sessions).

### R4 — Turn boundaries and "activity"
- **Decision**: Claude Code emits `working` on the first assistant line after a prompt; `done` on `stop_reason == end_turn`; silent turn end on `turn_duration` / `stop_hook_summary` system lines or a `[Request interrupted` marker; `compact_boundary` resets the loop streak. Activity = any bytes appended to the tracked log (one `usage` event per poll with new bytes).
- **Rationale**: local slash commands (`local_command`) log a prompt but no assistant reply, so arming on the prompt would produce false stalls; long thinking writes nothing, so "activity" must be bytes, not parsed lines.
- **Alternatives considered**: arm on prompt line (false stalls after local commands); hook-based start/stop (C-003 forbids new hooks).

### R5 — Pending tools
- **Decision**: Claude Code: set of `tool_use` ids without a matching `tool_result.tool_use_id`. Antigravity (no call ids): the tool calls of the latest `PLANNER_RESPONSE` count as pending until any later line arrives.
- **Rationale**: suppresses stalls during long builds/tests (US2 scenario 5).

### R6 — Loop fingerprint
- **Decision**: fingerprint = tool name + SHA-256 (CryptoKit) of the input serialized with `JSONSerialization` `.sortedKeys` (`input` for Claude Code, `args` for Antigravity). Streak counts adjacent tool calls; text/thinking does not break it; a different call, a new session or `compact_boundary` resets it; fires once at 4.
- **Rationale**: canonical serialization makes identical inputs compare equal regardless of key order; only hashes are retained (NFR-004). CryptoKit is a system framework (no supply-chain impact).
- **Alternatives considered**: `String.hashValue` (process-seeded, fine in-memory but less self-explanatory); comparing raw input strings (retains content).

### R7 — Session selection and seeding
- **Decision**: Claude Code tracks the most recently modified `~/.claude/projects/<project>/<session>.jsonl` (depth 1 only); lines with `isSidechain == true` are skipped. On start or session switch, read at most the last 256 KB, drop the first partial line, extract only the latest usage, emit one `usage` event with `seed = "true"`; loop/stall state starts fresh.
- **Rationale**: FR-004 / FR-014 / NFR-002; seeded readings above threshold mark the context warning as already fired so no stale bubble appears.

### R8 — Warning slot and approval override
- **Decision**: one `activeWarning`. Cleared by **Got it**, the same agent's `done`/`needsApproval`, or `setAgentEnabled(false)` for that agent; replaced by a newer warning. Another agent's `needsApproval` takes the bubble while `activeWarning` stays; the warning bubble is restored on that agent's next event. `working`, `almostDone` and other agents' `done` never replace it (decision `cross_agent_priority`, spec FR-010 amended).

### R9 — Supply chain
- **Decision**: no dependency added, upgraded or removed. CryptoKit is an Apple system framework. No adversarial-squad pass required (no security-impacting dependency decision).
