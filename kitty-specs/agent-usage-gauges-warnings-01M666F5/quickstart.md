# Quickstart: Verifying Agent Gauges & Warnings Manually

Prerequisites: `./Scripts/package_and_run.sh release` running; Claude and Antigravity enabled in Settings → AI Agents; speech bubbles on.

## 1. Drop-box events (any agent)

```bash
drop() { dir="$HOME/Library/Application Support/Bitz/agent-events"; mkdir -p "$dir"
  id=$(uuidgen | tr '[:upper:]' '[:lower:]'); ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '{"id":"%s","agentID":"claude","agentName":"Claude","kind":"%s","message":"%s","timestamp":"%s"%s}\n' \
    "$id" "$1" "$2" "$ts" "${3:+,\"metadata\":$3}" > "$dir/$id.json"; }

drop almostDone "✨ Claude is almost done!"                     # eager bubble, gone after ~6 s
drop usage "" '{"contextTokens":"185000"}'                      # gauge → Claude ctx 185k · 92%, context warning + amber visor
drop working "Claude is working..."                             # warning bubble stays
drop warning "⚠️ Claude reported a problem" '{"reason":"reported"}'  # replaces the context warning
```
Click **Got it** → bubble disappears, visor returns to its wellness color, clicks pass through the bubble area again.

## 2. Approval override

1. `drop warning "⚠️ Claude test" '{"reason":"reported"}'`
2. Same function with `agentID` changed to `antigravity` and kind `needsApproval` → approval bubble shows, visor stays amber.
3. Antigravity `working` → Claude's warning bubble returns.

## 3. Live Claude Code session

1. Start a Claude Code session; send a prompt → "Claude is working..." on first output; gauge shows `Claude ctx …`.
2. Turn ends → "Claude is done!"; no stall warning afterwards.
3. Run a long `sleep 300` tool call → no stall warning while it runs.

## 4. Settings

Settings → AI Agents → Agent Signals: toggle loop warnings off, set stall timeout to 10 min, set Claude window to 1M → gauge percent drops accordingly; relaunch keeps the values.

## 5. Resource check

Activity Monitor: Bitz stays < 2% CPU and < 70 MB RAM with an active Claude Code session over 5 minutes.
