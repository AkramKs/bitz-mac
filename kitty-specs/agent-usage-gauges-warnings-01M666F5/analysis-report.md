---
schema_version: 1
artifact_type: spec-kitty.analysis-report
command: /spec-kitty.analyze
mission_slug: agent-usage-gauges-warnings-01M666F5
mission_id: 01M666F5Z5VJTD1R7QXESMDY73
generated_at: '2026-10-30T13:54:15.573408+00:00'
analyzer_agent: unknown
input_artifacts:
  spec.md:
    path: kitty-specs/agent-usage-gauges-warnings-01M666F5/spec.md
    sha256: 35c114cd7adee478fe1cf511ec3c557d2adc9c9a34628f9d75b2eb7d0c590a38
  plan.md:
    path: kitty-specs/agent-usage-gauges-warnings-01M666F5/plan.md
    sha256: df9bdbe9d70f97020f1416c6451885e68e74e85c474ae9e8dff3143ff475e284
  tasks.md:
    path: kitty-specs/agent-usage-gauges-warnings-01M666F5/tasks.md
    sha256: c583df26622f754b39b84b6e43cb3cd959eaea79b92e0a2e85027086fb6d848c
  charter:
    path: .kittify/charter/charter.yaml
    sha256: 7651897089e056618a1c4b783e579dfc8dcb9cd1909fb35d03178ab10f1ca31f
verdict: blocked
issue_counts:
  high: 1
  low: 6
  medium: 6
  critical: 0
  info: 0
findings:
- id: C1
  severity: high
  category: charter
  summary: Charter quality gate 'zero compiler warnings' (and SwiftLint) is not reflected in any task; WP09 T042 only runs tests.
- id: C2
  severity: medium
  category: charter
  summary: 'DIR-004 interpretation: amber visor override makes the displayed visor diverge from the WellnessPointEngine visorColor mapping; plan asserts PASS without owner confirmation.'
- id: I1
  severity: medium
  category: inconsistency
  summary: Spec FR-004 says a user prompt marks the agent working; plan R4 and WP03/WP04 start working on the first assistant output after a prompt.
- id: I2
  severity: medium
  category: inconsistency
  summary: agentID 'claude' is shared by ProcessAgentAdapter (Claude desktop app) and the Claude Code session log; quitting the desktop app emits done and clears Claude Code warning/turn state.
- id: U1
  severity: medium
  category: underspecification
  summary: No manual acknowledgment path while another agent's approval overrides the bubble or bubbles are disabled; amber visor persists until the warning agent finishes.
- id: G1
  severity: medium
  category: coverage
  summary: SC-002 requires a replayed session; no end-to-end test feeds adapter events into AgentMonitorService.
- id: G2
  severity: medium
  category: coverage
  summary: NFR-003 (signal within 5 s) has no verification step; it is only design-implied by the 1.5 s poll.
- id: I3
  severity: low
  category: inconsistency
  summary: Session-selection hysteresis (10 s idle switch) exists only in WP03 T015; research R7 and data-model say 'most recently modified'.
- id: I4
  severity: low
  category: inconsistency
  summary: data-model warning-slot diagram restores the warning on the other agent's 'next event'; WP02 T010 excludes usage events.
- id: I5
  severity: low
  category: inconsistency
  summary: plan Project Structure omits AgentModelsTests.swift and AgentWarningPresentationTests.swift, and lists SettingsIntegrationTests.swift which no WP owns.
- id: I6
  severity: low
  category: inconsistency
  summary: Plan/tasks reset the loop streak on compaction; spec FR-008 names only a different call or a new session.
- id: O1
  severity: low
  category: ownership
  summary: WP01 T004 edits AgentMonitorService.swift and SpeechBubbleView.swift (owned by WP02/WP06) with placeholder cases; documented out-of-map edit.
- id: T1
  severity: low
  category: terminology
  summary: Spec canonical term is 'session log'; code types use 'Transcript' (ClaudeCodeTranscriptAdapter) to match the existing AntigravityTranscriptAdapter.
---

## Specification Analysis Report

Mission `agent-usage-gauges-warnings-01M666F5` (GitHub #38). Artifacts analysed: spec.md, plan.md, tasks.md + 9 WP prompts, research.md, data-model.md, contracts/agent-event-contract.md, `.kittify/charter/charter.md`. Verified facts used: `xcrun swift build` currently reports 0 warnings; no `.swiftlint.yml` exists and CI (`.github/workflows/ci.yml`) runs `swift test` only.

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| C1 | Charter | HIGH | charter.md §3; plan.md Charter Check; tasks WP09 T042 | Quality gate "SwiftLint with zero compiler warnings" has no task; Charter Check does not mention it. | Add a zero-warnings `xcrun swift build` check to WP09 T042 and to each code WP's Definition of Done; record in Charter Check that SwiftLint is not configured in the repo/CI (gate enforced as zero compiler warnings only). |
| C2 | Charter | MEDIUM | charter.md DIR-004; plan.md Charter Check; WP06 T027 | Visible visor diverges from the engine's visorColor while a warning is active; Rive inputs unchanged, so PASS is an interpretation. | Keep the design, but state the interpretation in the PR and in `docs/STATE_MACHINE.md` (WP09 T040) and ask the charter owner to confirm at review. |
| I1 | Inconsistency | MEDIUM | spec.md FR-004; research.md R4; WP03 T016; WP04 T020 | Spec: prompt marks working. Tasks: first assistant output marks working (avoids false turns from local commands). | Amend FR-004 wording to "the agent's first reply to a prompt marks it working". |
| I2 | Inconsistency | MEDIUM | AgentModels builtInCatalog `claude`; ProcessAgentAdapter; WP04 T021 | Desktop app quit → `done` for `claude` → clears Claude Code warning and turn state. | Add a spec edge case documenting the shared identity as an accepted limitation, or have WP02 ignore `done` from the process adapter for warning clearing. Decision needed. |
| U1 | Underspecification | MEDIUM | spec.md FR-010/FR-011/FR-013; WP02 T010; WP06 | With an approval override or bubbles disabled, there is no way to acknowledge a warning manually. | Either accept and document in spec Edge Cases, or add a "Dismiss agent warning" item to the menu bar dropdown (BitzApp.swift, WP06). |
| G1 | Coverage | MEDIUM | spec.md SC-002; WP02 T013; WP04 T022 | Policy tests use synthetic events; adapter tests stop at emitted events. | Add one integration test (WP06): Claude fixture → `ClaudeCodeTranscriptAdapter` → `AgentMonitorService` → `activeWarning` set once. |
| G2 | Coverage | MEDIUM | spec.md NFR-003; WP09 T043 | 5 s timeliness is not measured anywhere. | Add a timed step to WP09 T043 (drop-box event → bubble ≤ 5 s) or cover with an adapter-poll + monitor test using the real poll interval. |
| I3 | Inconsistency | LOW | research.md R7; data-model.md; WP03 T015 | Hysteresis rule only in tasks. | Add the 10 s idle-switch rule to research R7. |
| I4 | Inconsistency | LOW | data-model.md Warning slot; WP02 T010 | "Next event" vs usage exclusion. | Say "next lifecycle event (not usage)" in data-model. |
| I5 | Inconsistency | LOW | plan.md Project Structure; WP01; WP06 | Test file list drift. | Update plan structure list. |
| I6 | Inconsistency | LOW | spec.md FR-008; research.md R6; WP03 T016 | Compaction reset not in spec. | Add "or a compaction" to FR-008. |
| O1 | Ownership | LOW | WP01 T004 | Out-of-map placeholder edits. | Accept; reviewers check that WP02/WP06 replace the placeholders. |
| T1 | Terminology | LOW | spec.md Domain Language; WP04 | "Transcript" in type names vs "session log". | Accept (matches existing class naming); keep "session log" in user-facing text. |

**Coverage Summary Table:**

| Requirement Key | Has Task? | Task IDs | Notes |
|-----------------|-----------|----------|-------|
| FR-001 almost-done-event | Yes | T001, T010, T026, T029 | |
| FR-002 warning-event | Yes | T001, T009 | |
| FR-003 event-details | Yes | T001, T002, T005, T006 | |
| FR-004 claude-session-tracking | Yes | T020, T021, T022, T028 | See I1 |
| FR-005 context-usage-measure | Yes | T008, T020, T023 | |
| FR-006 context-gauge-display | Yes | T032, T033, T034 | |
| FR-007 context-warning | Yes | T008, T013 | |
| FR-008 loop-warning | Yes | T016, T017, T019, T020, T023 | See I6 |
| FR-009 stall-warning | Yes | T011, T013, T016 | |
| FR-010 warning-lifecycle | Yes | T009, T010, T026, T030 | See U1 |
| FR-011 amber-visor | Yes | T027, T031 | See C2 |
| FR-012 signal-settings | Yes | T003, T007, T035, T036, T037, T038 | |
| FR-013 existing-toggles | Yes | T012, T035 | See U1 |
| FR-014 quiet-startup | Yes | T008, T014, T021, T024 | |
| NFR-001 incremental-reads | Yes | T014, T018, T043 | |
| NFR-002 bounded-memory | Yes | T014, T018 | |
| NFR-003 timeliness | Partial | T011 | No verification (G2) |
| NFR-004 privacy | Partial | T016, T020 | Review-only, no automated check |
| NFR-005 test-isolation | Yes | T007, T013 | |
| NFR-006 robust-parsing | Yes | T006, T020, T022, T023 | |
| C-001 platform | Yes | all code WPs | Zero-warnings gate missing (C1) |
| C-002 overlay-invariants | Yes | T026, T030 | |
| C-003 no-new-hooks | Yes | T021 | |
| C-004 no-invented-data | Yes | T039, T041 | |
| C-005 nothing-outside-window | Yes | T029 | |
| C-006 stacked-on-pr-62 | Yes | WP06 context | Process constraint |

**Charter Alignment Issues:** C1 (quality gate missing from tasks), C2 (DIR-004 interpretation needs owner confirmation). DIR-001, DIR-002, DIR-003, DIR-005 and the TDD policy are covered.

**Unmapped Tasks:** None. Every T001–T043 maps to at least one requirement or success criterion.

**Metrics:**

- Total Requirements: 26 (14 FR, 6 NFR, 6 C) + 6 success criteria
- Total Tasks: 43 subtasks in 9 work packages
- Coverage: 100% of requirements have ≥ 1 task (2 partial: NFR-003, NFR-004)
- Ambiguity Count: 1 (U1)
- Duplication Count: 0
- Critical Issues Count: 0 (1 high)

### Next Actions

- Resolve C1 before `/spec-kitty.implement` (blocking: high). Small edit to WP09 T042, the code WPs' Definition of Done, and plan Charter Check.
- Decide I2 and U1 (product decisions), then apply I1, I3–I6 wording fixes via a spec/plan refinement.
- G1/G2: add one integration test to WP06 and a timed check to WP09 T043.
- Re-run `/spec-kitty.analyze` after remediation to reach `ready`.
