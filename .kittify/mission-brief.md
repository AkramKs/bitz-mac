<!-- spec-kitty intake: ingested from issues/2026-10-29-settings-window-mascot-behavior.md at 2026-10-29T13:29:13.355387+00:00 -->
<!-- brief_hash: 93070d60540e8fa91111b1d37c2a5da02a98c53038adc329dacd1079b3bd2024 -->

## Summary
Introduce a dedicated macOS Settings / Preferences window to configure mascot behaviors, appearance, telemetry, and AI agent monitoring, decluttering the menu bar dropdown into a lightweight, glanceable menu.

## Environment
- **Product/Service**: bitz-mac (Bitz the Cyber Cat)
- **Region/Version**: current `main`
- **Browser/OS**: macOS 14.0+ (Apple Silicon)

## Problem / Motivation
Currently, all mascot controls, configuration options, and diagnostic tools live directly inside the `MenuBarExtra` dropdown (`BitzMenuBarContentView`). Even with submenu grouping, the menu has grown overloaded with:
- Mascot size and opacity steppers and presets
- Screen corner anchoring and dragging toggles
- Multi-monitor routing and connected screen lists
- Telemetry metrics toggles, display placements, polling cadence, and disk warning thresholds
- Hardware sensor outputs, manual sampling triggers, and productive/distraction rule actions
- Monitored AI agents, popup alerts, and hook installer actions
- State simulation buttons and keybinds cheat sheet
- Update checker and login items

Interacting with nested submenus inside a transient MenuBarExtra dropdown is cumbersome and prone to accidental dismissals. Menu bar menus are meant for fast, glanceable status and quick actions, while rich customization belongs in a dedicated macOS Settings window.

## Reproduction Steps
1. Launch Bitz on macOS.
2. Click the Bitz cat icon in the macOS menu bar.
3. Observe a deep, multi-tiered list of submenus and controls covering appearance, dragging, multi-monitor routing, telemetry toggles, hardware sensors, AI agents, simulator overrides, and update settings.
4. Try configuring multiple telemetry metrics or sensor rules; the menu closes after each interaction.

## Expected Behavior
- The menu bar dropdown is lightweight and glanceable:
  - Current mascot state, streak, and focus PTS.
  - Quick actions (e.g., "Pet Bitz", "Unlock / Lock Position").
  - Concise active alert summary (e.g., active agent or thermal warning, if applicable).
  - A clean `Settings...` menu item (with standard `⌘,` shortcut) that opens a dedicated Settings window.
  - Minimal lifecycle items (`Check for Updates...`, `Quit Bitz`).
- Clicking `Settings...` opens a native, tabbed macOS Preferences / Settings window where users can comfortably configure all mascot behaviors, telemetry, and integrations without the dropdown closing.

## Actual Behavior
There is no Settings window. All controls, configurations, and diagnostic toggles are packed into `BitzMenuBarContentView`, making the menu bar extra crowded and difficult to navigate.

## Proposed Solution: Dedicated Settings Window

Implement a native macOS Settings scene (or `NSWindowController` with `NSHostingController`) structured into intuitive tabs:

### 1. General & Mascot Appearance
- **Mascot Scale**: Steppers, slider, and size presets (Tiny to Massive).
- **Opacity**: Slider and presets (20% to 100%).
- **Positioning**: Default screen corner anchor picker, drag unlock/lock toggle, edge snap padding.
- **Display Target**: Primary display, follow active screen, or pin to a specific display.

### 2. Behaviors & Wellness Engine
- **Focus & Rest Cadence**: Continuous work warning threshold (e.g., 50 min overworked, 90 min burnout), break recharge rate.
- **App Classification Rules**: Manage custom productive vs. dopamine drain application list.
- **Interactions**: Petting cooldown, audio effects / cyber purr volume toggles (refs #21).

### 3. AI Coding Agents
- **Popup Notifications**: Toggle speech bubble alerts for agent completion and approval requests.
- **Monitored Agents**: Enable/disable detection per agent (Claude Code, Gemini CLI, Antigravity, Cursor, Windsurf, Copilot, Codex, etc.).
- **Hook Integration**: Install / uninstall Claude Code hook buttons with status indicators.
- **Custom Agents**: Register custom process names, bundle IDs, or log paths.

### 4. Telemetry & Hardware Sensors
- **Visible Metrics**: Checkbox list for Disk, RAM, CPU Load/Die Temp, GPU, FPS, Network, Battery.
- **Display Placements**: Menu bar title, mascot Cyber HUD, speech bubble carousel, or menu bar dropdown.
- **Sampling Cadence**: Polling interval picker (1s, 3s, 5s, 10s).
- **Warning Thresholds**: Low disk space alert threshold, CPU overheat threshold.

### 5. Diagnostics & Advanced
- **State Simulation**: Quick override triggers for testing states (Super Charged, Balanced, Dopamine Overload, Overworked, Burnout, Charging, Overheat).
- **Keyboard Shortcuts Reference**: Cheat sheet of all global and local keybinds.
- **Updates & System**: Automatic update check toggle, manual update checker, Launch at Login toggle.

## Acceptance Criteria
- [ ] Add a native macOS `Settings` window (or preferences window) accessible via `⌘,` and via a `Settings...` item in the menu bar dropdown.
- [ ] Group configuration into organized tabs (`General`, `Behaviors`, `AI Agents`, `Telemetry`, `Advanced`).
- [ ] Slim down `BitzMenuBarContentView` to focus strictly on glanceable status, quick actions, `Settings...`, and `Quit`.
- [ ] Settings window does not interfere with the transparent click-through mascot panel (`MascotOverlayPanel.ignoresMouseEvents` invariant preserved).
- [ ] Settings changes take effect immediately across all stores (`AvatarScaleStore`, `AvatarOpacityStore`, `AvatarPositionStore`, `DisplayPreferenceStore`, `TelemetrySettingsStore`, `AgentMonitorService`).
- [ ] Unit tests cover settings window initialization and user default synchronization.

## Impact
**Medium / High** - Significantly improves user experience and ergonomics by uncluttering the menu bar extra and establishing a scalable foundation for upcoming mascot customization features.

## Additional Context
- Follows Apple Human Interface Guidelines for macOS Settings / Preferences windows.
- Complements ongoing feature work for custom color palettes (#28), per-emotion color panel (#31), and mascot roster (#30), which can now be housed elegantly in Settings tabs rather than bloating the menu bar.
