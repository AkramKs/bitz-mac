# Mission Specification: Dedicated Settings Window & Streamlined Menu Bar Dropdown

**Mission Branch**: `feat/issue-49-settings-window`  
**Created**: 2026-10-29  
**Status**: Draft  
**Input**: User request: "our menu dropdown is getting too mutch maybe we need a setiings button to customize our mascot behavors etc so it is a less loaded dropdown menu" (Tracks GitHub issue #49)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Dedicated macOS Settings Window & Menu Entry (Priority: P1)

A user opens the macOS Settings window either by clicking a clean "Settings..." entry in the menu bar dropdown or by pressing the standard macOS `⌘,` keyboard shortcut. The window provides an organized, tabbed interface for all Bitz customizations.

**Why this priority**: Core architectural change separating glanceable menu bar status from in-depth configuration, unblocking all future mascot customizations.

**Independent Test**: Launch Bitz, click menu bar icon, click "Settings..." (or press `⌘,`). A native Settings window appears with standard window controls, keyboard focus, and tabs.

**Acceptance Scenarios**:

1. **Given** Bitz is running, **When** the user clicks "Settings..." in the menu bar dropdown, **Then** the Settings window opens and becomes key.
2. **Given** any window or the desktop is active, **When** the user activates Bitz and presses `⌘,`, **Then** the Settings window is brought to front.
3. **Given** the Settings window is open, **When** the user closes or minimizes it, **Then** the transparent mascot overlay panel remains intact with full click-through (`ignoresMouseEvents = true`).

---

### User Story 2 - Streamlined, Glanceable Menu Bar Dropdown (Priority: P1)

The menu bar dropdown is slimmed down from an overwhelming 35+ item nested hierarchy into an ultra-clean, glanceable popover.

**Why this priority**: Resolves user friction and visual overload on small screens and laptops where nested menus get cut off or accidentally dismissed.

**Independent Test**: Click Bitz in the menu bar. The menu contains under 10 top-level items with no deep nested configuration submenus.

**Acceptance Scenarios**:

1. **Given** normal operation, **When** opening the menu bar dropdown, **Then** the user sees:
   - Status header (Mascot state, Focus streak, Points PTS)
   - Quick action: "Pet Bitz (<3) [P]"
   - Quick toggle: "Lock/Unlock Position" (if applicable)
   - Active status banner: (e.g. active agent task or low-disk/thermal warning, if active)
   - Divider
   - "Settings... [⌘,]"
   - "Check for Updates..."
   - "Quit Bitz [⌘Q]"
2. **Given** the streamlined dropdown, **When** clicked, **Then** it does not overflow or lag.

---

### User Story 3 - Mascot & Appearance Customization Tab (Priority: P2)

Users configure avatar scale, opacity, corner anchoring, drag-to-move lock, and multi-monitor routing from the "General / Appearance" settings tab.

**Why this priority**: Centralizes mascot placement and visual controls into a stable, non-transient window.

**Independent Test**: Change size to 150% and opacity to 80% in the Settings window; the mascot overlay updates immediately in real-time.

**Acceptance Scenarios**:

1. **Given** the Settings window is open to "Appearance", **When** the user adjusts scale or opacity presets/sliders, **Then** the mascot overlay updates live and persists to `UserDefaults`.
2. **Given** multiple displays connected, **When** the user selects "Primary Screen", "Follow Active Screen", or a specific screen, **Then** `DisplayPreferenceStore` updates immediately.

---

### User Story 4 - Behaviors & Wellness Engine Tab (Priority: P2)

Users configure focus duration, break thresholds, custom productive/distraction application classifications, and interaction sounds.

**Why this priority**: Fulfills the user's specific request to "customize our mascot behaviors" in a dedicated surface.

**Independent Test**: Add an app to the custom productive/distraction list; verify the classification applies on the next sensor tick.

**Acceptance Scenarios**:

1. **Given** the "Behaviors" tab, **When** adjusting overworked or burnout minute thresholds, **Then** `WellnessPointEngine` applies the new bounds.
2. **Given** frontmost application rules, **When** adding or resetting an app rule, **Then** `ActivityMonitorService` synchronizes custom rules instantly.

---

### User Story 5 - AI Agents & Telemetry Tabs (Priority: P2)

Dedicated tabs for AI Coding Agents and Telemetry/Diagnostics.

**Why this priority**: Eliminates the largest sources of menu bar bloat (agent lists, hooks installer, metric toggles, polling cadence, placement toggles).

**Independent Test**: Toggle telemetry metrics or install Claude Code hooks from the Settings tab without any transient menu disappearing.

**Acceptance Scenarios**:

1. **Given** the "AI Agents" tab, **When** toggling popup alerts or monitored agents, **Then** `AgentMonitorService` updates immediately.
2. **Given** the "Telemetry" tab, **When** choosing visible metrics and display placements (Cyber HUD, speech bubble, menu bar title), **Then** `TelemetrySettingsStore` updates live.

---

### User Story 6 - Diagnostics & Advanced Tab (Priority: P3)

State simulation triggers, keyboard shortcuts reference, and system lifecycle options (Launch at Login, update cadence).

**Why this priority**: Diagnostic tools remain easily accessible for development, testing, and power users without cluttering daily casual use.

**Independent Test**: Select "Super Charged (90 PTS)" in Diagnostics; the mascot transitions to Super Charged state.

**Acceptance Scenarios**:

1. **Given** the Diagnostics tab, **When** clicking a simulated state button, **Then** the manual override is activated.
2. **Given** the "Launch at Login" toggle, **When** switched, **Then** `SMAppService.mainApp` registration updates.

---

### Edge Cases

- **Opening Settings repeatedly**: Subsequent triggers of `⌘,` or clicking "Settings..." must focus the existing Settings window rather than spawning duplicate windows.
- **Overlay Window Invariant**: Opening, moving, or resizing the Settings window must never steal key window privileges or change `ignoresMouseEvents` on the floating `MascotOverlayPanel`.
- **Display Disconnect**: If Settings window is on a disconnected secondary display, macOS window restoration must clamp it back to the primary display.
- **Headless / Background launch**: Bitz running at login must not pop up the Settings window automatically on boot.

## Requirements *(mandatory)*

### Functional Requirements

| ID | Title | User Story | Priority | Status |
|----|-------|------------|----------|--------|
| FR-001 | Native macOS Settings Window | As a user, I want a standard Settings window (`⌘,`) so I can configure Bitz comfortably without transient menus closing. | High | Open |
| FR-002 | Streamlined Menu Bar Dropdown | As a user, I want a concise, fast-glance menu bar menu so that my display is not cluttered with deep nested submenus. | High | Open |
| FR-003 | Settings Button in Menu Bar | As a user, I want a clear "Settings..." button in the menu bar dropdown to open the settings window. | High | Open |
| FR-004 | Appearance Settings Tab | As a user, I want to configure mascot scale, opacity, position anchors, and display routing in Settings. | High | Open |
| FR-005 | Behaviors & Wellness Tab | As a user, I want to configure work streak limits, break reminders, and productive app rules in Settings. | Medium | Open |
| FR-006 | AI Agents Settings Tab | As a user, I want to manage monitored agents, speech bubble popups, and hook installers in Settings. | Medium | Open |
| FR-007 | Telemetry Settings Tab | As a user, I want to toggle visible metrics, HUD placements, and warning thresholds in Settings. | Medium | Open |
| FR-008 | Diagnostics & Shortcuts Tab | As a developer or power user, I want state simulators and keybind references in an Advanced tab. | Low | Open |

### Non-Functional Requirements

| ID | Title | Requirement | Category | Priority | Status |
|----|-------|-------------|----------|----------|--------|
| NFR-001 | Click-Through Safety | The mascot overlay window MUST maintain `ignoresMouseEvents = true` regardless of Settings window state. | Reliability | High | Open |
| NFR-002 | Instant State Propagation | Settings updates must reflect immediately across existing `@ObservedObject` stores without app restart. | Performance | High | Open |
| NFR-003 | Menu Dropdown Height | Streamlined menu bar dropdown must stay under 300 pt in vertical height for any screen resolution. | Usability | High | Open |
| NFR-004 | Native macOS HIG | Use native macOS tabbed settings styling (`TabView` with `.tabViewStyle(.sidebarAdaptable)` or standard toolbar style). | Usability | Medium | Open |

### Constraints

| ID | Title | Constraint | Category | Priority | Status |
|----|-------|------------|----------|----------|--------|
| C-001 | macOS 14.0+ | Support macOS 14.0 Sonoma and newer on Apple Silicon. | Platform | High | Open |
| C-002 | No Focus Stealing | Mascot panel must remain `.nonactivatingPanel` with `canBecomeKey = false`. | Architecture | High | Open |
| C-003 | Single Settings Instance | Only one Settings window instance may exist at any time. | Architecture | Medium | Open |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Menu bar dropdown root items reduced from >35 items/submenus to <8 essential items.
- **SC-002**: Pressing `⌘,` or clicking "Settings..." opens the Settings window in <300ms.
- **SC-003**: 100% of mascot customizations (scale, opacity, corners, telemetry, agents, app rules) are fully functional inside Settings tabs.
- **SC-004**: All automated unit tests in `Tests/` pass with zero regressions.
