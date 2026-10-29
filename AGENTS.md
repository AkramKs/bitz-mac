# AGENTS.md — Agent & Contributor Workflow Invariants

This file establishes mandatory engineering, git, and lifecycle invariants for all AI coding agents (Antigravity, Claude Code, Cursor, Codex, etc.) and human contributors working on `bitz-mac`.

---

## 🔒 1. Issue Ticket & PR Lifecycle (STRICT)

### Rule 1.1: Ticket First
- Never write code or open a PR without an associated GitHub Issue ticket.
- If working on a new feature, bug fix, or refactor, first check open issues (`gh issue list --repo AkramKs/bitz-mac`).
- If no ticket exists, create one (`gh issue create`) before branching.

### Rule 1.2: Explicit Ticket References in PRs
- Every Pull Request MUST reference its issue ticket in both the commit message and PR body:
  - `Closes #<id>` and `refs #<id>`
- This ensures automated CI passes `.github/workflows/pr-ticket-check.yml`.

### Rule 1.3: Mandatory Post-Merge Issue Closure
> **CRITICAL RULE**: When a Pull Request is merged into `main`, you MUST immediately verify that the linked issue ticket is officially **CLOSED**.
>
> 1. Check issue status: `gh issue view <id> --repo AkramKs/bitz-mac`
> 2. If the ticket remains open for any reason, immediately close it:
>    ```bash
>    gh issue close <id> --repo AkramKs/bitz-mac --comment "Resolved and merged into main via PR #<pr_number>."
>    ```
> 3. **Never leave completed issue tickets open after a PR is done.**

### Rule 1.4: Branch Sync & Cleanup
- Immediately after merging a PR:
  1. Switch back to `main`: `git checkout main`
  2. Pull latest upstream commits: `git pull origin main`
  3. Delete the local feature branch: `git branch -D <branch>`
  4. Ensure `git status` reports working directory clean.

---

## 🐱 2. Mascot & Window Invariants

1. **100% Click-Through Guarantee**:
   - `MascotOverlayPanel.ignoresMouseEvents` must remain `true` at all times during normal operation.
   - It may only temporarily switch to `false` when:
     - The user is dragging/moving the mascot (`positionStore.isInteractivityEnabled == true`).
     - An interactive speech bubble alert is active (e.g., Update Download button or Agent Approval bubble).
   - Once dismissed or locked, it MUST immediately revert to `ignoresMouseEvents = true`.

2. **Zero Keyboard Focus Stealing**:
   - The mascot panel must always be `.nonactivatingPanel` with `canBecomeKey = false`.
   - Modifiers and keybinds (`⌥ Option`, `⎋ Escape`, `⏎ Return`) must use global/local event monitors without making the panel key window or stealing focus from the user's IDE or terminal.

3. **Multi-Display & Screen Clamping**:
   - Bitz must never be positioned off-screen or stranded behind a disconnected display.
   - Screen boundary clamping (`clampOriginToVisibleFrame`) and magnetic edge snapping (~20pt) must be preserved.

---

## 🧪 3. Verification & Build Invariants

1. **Toolchain Execution**:
   - Always run with Xcode Swift toolchain: `/usr/bin/swift` or `xcrun swift`. Never rely on bare `swift` from `.swiftly` or third-party path overrides.
2. **Deterministic Tests**:
   - Run the full test suite before pushing: `xcrun swift test`.
   - All tests must pass with zero failures.
   - Every store or service test must use an isolated `UserDefaults(suiteName:)` domain with cleanup in `defer { defaults.removePersistentDomain(...) }`.
3. **Local Packaging**:
   - Test packaging and run locally with `./Scripts/package_and_run.sh release` to confirm signing and live AppKit execution.

---

## 📄 4. Ownership & Legal Policy

- Bitz is exclusively owned by **Akram Kasimi**.
- Released under a **Source-Available & Personal Hobbyist License** (see [LICENSE](LICENSE)).
- Personal, educational, and hobbyist use is permitted.
- Commercial redistribution, resale, white-labeling, or unauthorized commercial cloning is strictly prohibited.
