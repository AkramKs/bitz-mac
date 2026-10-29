import AppKit
import Combine
import ServiceManagement
import SwiftUI

/// Application delegate managing the transparent `MascotOverlayPanel`, `WellnessPointEngine`,
/// `ActivityMonitorService`, `AvatarScaleStore`, and `AvatarOpacityStore` lifecycle (`FR-001`, `FR-005`, `FR-006`).
@MainActor
public final class BitzAppDelegate: NSObject, NSApplicationDelegate {
    public let riveController: ProductionRiveController
    public let engine: WellnessPointEngine
    public let activityMonitor: ActivityMonitorService
    public let scaleStore: AvatarScaleStore
    public let opacityStore: AvatarOpacityStore
    public let positionStore: AvatarPositionStore
    public let displayStore: DisplayPreferenceStore
    public let agentMonitor: AgentMonitorService
    public let updateStore: AppUpdateStore
    public private(set) var overlayPanels: [MascotOverlayPanel] = []
    public var overlayPanel: MascotOverlayPanel? { overlayPanels.first }

    nonisolated(unsafe) private var screenParametersObserverToken: (any NSObjectProtocol)?
    nonisolated(unsafe) private var appActivationObserverToken: (any NSObjectProtocol)?
    nonisolated(unsafe) private var localFlagsMonitor: Any?
    nonisolated(unsafe) private var globalFlagsMonitor: Any?
    nonisolated(unsafe) private var localKeyMonitor: Any?
    nonisolated(unsafe) private var globalKeyMonitor: Any?
    private var updateStoreCancellable: AnyCancellable?
    private var screenReconfigTask: Task<Void, Never>?

    public override convenience init() {
        self.init(
            riveController: ProductionRiveController(),
            telemetryProvider: SystemActivityTelemetryProvider(),
            scaleStore: AvatarScaleStore(),
            opacityStore: AvatarOpacityStore(),
            positionStore: AvatarPositionStore(),
            displayStore: DisplayPreferenceStore(),
            updateStore: AppUpdateStore()
        )
    }

    public init(
        riveController: ProductionRiveController = ProductionRiveController(),
        telemetryProvider: ActivityTelemetryProviding = SystemActivityTelemetryProvider(),
        scaleStore: AvatarScaleStore = AvatarScaleStore(),
        opacityStore: AvatarOpacityStore = AvatarOpacityStore(),
        positionStore: AvatarPositionStore = AvatarPositionStore(),
        displayStore: DisplayPreferenceStore = DisplayPreferenceStore(),
        updateStore: AppUpdateStore = AppUpdateStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.riveController = riveController
        self.engine = WellnessPointEngine(riveController: riveController, userDefaults: userDefaults)
        self.activityMonitor = ActivityMonitorService(engine: self.engine, telemetry: telemetryProvider)
        self.scaleStore = scaleStore
        self.opacityStore = opacityStore
        self.positionStore = positionStore
        self.displayStore = displayStore
        self.updateStore = updateStore

        // Wire agent detection adapters
        let processAdapter = ProcessAgentAdapter()
        let dropboxAdapter = DropboxAgentAdapter()
        let antigravityAdapter = AntigravityTranscriptAdapter()
        self.agentMonitor = AgentMonitorService(adapters: [processAdapter, dropboxAdapter, antigravityAdapter])

        super.init()

        self.scaleStore.onScaleChanged = { [weak self] newScale in
            self?.overlayPanels.forEach { $0.applyScaleFactor(newScale) }
        }
        self.positionStore.onCornerChanged = { [weak self] newCorner in
            self?.overlayPanels.forEach { $0.applyCornerAnchor(newCorner) }
        }
        self.positionStore.onCustomPositionChanged = { [weak self] newOrigin in
            self?.overlayPanels.forEach { $0.applyCustomOrigin(newOrigin) }
        }
        self.positionStore.onInteractivityToggled = { [weak self] _ in
            self?.updatePanelsInteractivity()
        }
        self.updateStoreCancellable = self.updateStore.$isSpeechBubbleAlertActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePanelsInteractivity()
            }
        self.displayStore.onDisplayPreferenceChanged = { [weak self] in
            self?.syncOverlayPanels()
        }

        self.screenParametersObserverToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleScreenParametersChangedDebounced()
            }
        }

        self.appActivationObserverToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.displayStore.targetMode == .followActive else { return }
                self.syncOverlayPanels()
            }
        }

        self.localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let optionHeld = event.modifierFlags.contains(.option)
            self?.positionStore.setModifierHeld(optionHeld)
            return event
        }

        self.globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let optionHeld = event.modifierFlags.contains(.option)
            Task { @MainActor [weak self] in
                self?.positionStore.setModifierHeld(optionHeld)
            }
        }

        self.localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.positionStore.isPositionUnlocked else { return event }
            // Escape (53) or Return (36) immediately locks position
            if event.keyCode == 53 || event.keyCode == 36 {
                self.positionStore.lockPosition()
                return nil
            }
            return event
        }

        self.globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.positionStore.isPositionUnlocked else { return }
            // Escape (53) or Return (36) immediately locks position
            if event.keyCode == 53 || event.keyCode == 36 {
                Task { @MainActor [weak self] in
                    self?.positionStore.lockPosition()
                }
            }
        }
    }

    deinit {
        screenReconfigTask?.cancel()
        if let token = screenParametersObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = appActivationObserverToken {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        if let local = localFlagsMonitor {
            NSEvent.removeMonitor(local)
        }
        if let global = globalFlagsMonitor {
            NSEvent.removeMonitor(global)
        }
        if let localKey = localKeyMonitor {
            NSEvent.removeMonitor(localKey)
        }
        if let globalKey = globalKeyMonitor {
            NSEvent.removeMonitor(globalKey)
        }
    }

    public func updatePanelsInteractivity() {
        let isInteractive = positionStore.isInteractivityEnabled || updateStore.isSpeechBubbleAlertActive
        overlayPanels.forEach { $0.ignoresMouseEvents = !isInteractive }
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp?.setActivationPolicy(.accessory)
        setupOverlayPanel()
        activityMonitor.startMonitoring()
        agentMonitor.startMonitoring()
        updateStore.startPeriodicChecks()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        activityMonitor.stopMonitoring()
        agentMonitor.stopMonitoring()
        updateStore.stopPeriodicChecks()
        engine.persistState()
    }

    /// Instantiates and positions the borderless, click-through `MascotOverlayPanel`(s)
    /// hosting `MascotOverlayView` according to the active `displayStore.targetMode`.
    public func setupOverlayPanel() {
        syncOverlayPanels()
    }

    /// Synchronizes overlay panels across screens based on `displayStore.targetMode`.
    public func syncOverlayPanels() {
        displayStore.refreshConnectedScreens()

        if displayStore.targetMode == .allDisplays {
            let screens = NSScreen.screens
            while overlayPanels.count > screens.count {
                let panel = overlayPanels.removeLast()
                panel.orderOut(nil)
            }
            for (index, screen) in screens.enumerated() {
                let panel: MascotOverlayPanel
                if index < overlayPanels.count {
                    panel = overlayPanels[index]
                } else {
                    panel = createConfiguredPanel()
                    overlayPanels.append(panel)
                }
                panel.assignedScreen = screen
                panel.applyScaleFactor(CGFloat(scaleStore.scaleFactor), on: screen)
                if let customOrigin = positionStore.customOrigin {
                    panel.applyCustomOrigin(customOrigin, on: screen)
                } else {
                    panel.applyCornerAnchor(positionStore.cornerAnchor, on: screen)
                }
                panel.orderFrontRegardless()
            }
        } else {
            let targetScreen = displayStore.resolveScreen()
            while overlayPanels.count > 1 {
                let panel = overlayPanels.removeLast()
                panel.orderOut(nil)
            }
            let panel: MascotOverlayPanel
            if let existing = overlayPanels.first {
                panel = existing
            } else {
                panel = createConfiguredPanel()
                overlayPanels.append(panel)
            }
            panel.assignedScreen = targetScreen
            panel.applyScaleFactor(CGFloat(scaleStore.scaleFactor), on: targetScreen)
            if let customOrigin = positionStore.customOrigin {
                panel.applyCustomOrigin(customOrigin, on: targetScreen)
            } else {
                panel.applyCornerAnchor(positionStore.cornerAnchor, on: targetScreen)
            }
            panel.orderFrontRegardless()
        }
    }

    /// Debounces display change notifications to prevent stutter and layout flashes.
    public func handleScreenParametersChangedDebounced() {
        screenReconfigTask?.cancel()
        screenReconfigTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.syncOverlayPanels()
        }
    }

    private func createConfiguredPanel() -> MascotOverlayPanel {
        let panel = MascotOverlayPanel()
        panel.ignoresMouseEvents = !(positionStore.isInteractivityEnabled || updateStore.isSpeechBubbleAlertActive)
        panel.onRightMouseDown = { [weak self] in
            Task { @MainActor [weak self] in
                self?.positionStore.lockPosition()
            }
        }
        let rootView = MascotOverlayView(
            engine: engine,
            scaleStore: scaleStore,
            opacityStore: opacityStore,
            positionStore: positionStore,
            agentMonitor: agentMonitor,
            updateStore: updateStore,
            onDragChanged: { [weak panel] origin, _ in
                panel?.setFrameOrigin(origin)
            },
            onDragEnded: { [weak self, weak panel] finalOrigin, targetScreen in
                panel?.applyCustomOrigin(finalOrigin, on: targetScreen)
                if let targetScreen, let targetID = targetScreen.displayID {
                    if self?.displayStore.targetMode == .specific {
                        self?.displayStore.selectSpecificDisplay(id: targetID, name: targetScreen.localizedName)
                    }
                }
            },
            onGetOrigin: { [weak panel] in
                panel?.frame.origin
            },
            onGetSize: { [weak panel] in
                panel?.frame.size ?? MascotOverlayPanel.defaultPanelSize
            }
        )
        let hostingView = NSHostingView(rootView: rootView)
        let initialSize = MascotOverlayPanel.calculatePanelSize(for: CGFloat(scaleStore.scaleFactor))
        hostingView.frame = NSRect(origin: .zero, size: initialSize)
        panel.contentView = hostingView
        return panel
    }
}

/// Observable Menu Bar content view displaying live hardware sensor telemetry,
/// wellness score, manual avatar resizing & opacity controls, and interactive state controls.
@MainActor
struct BitzMenuBarContentView: View {
    @ObservedObject var engine: WellnessPointEngine
    @ObservedObject var activityMonitor: ActivityMonitorService
    @ObservedObject var scaleStore: AvatarScaleStore
    @ObservedObject var opacityStore: AvatarOpacityStore
    @ObservedObject var positionStore: AvatarPositionStore
    @ObservedObject var displayStore: DisplayPreferenceStore
    @ObservedObject var agentMonitor: AgentMonitorService
    @ObservedObject var updateStore: AppUpdateStore

    @State private var launchAtLoginEnabled: Bool = (SMAppService.mainApp.status == .enabled)
    @State private var hookActionMessage: String? = nil
    @State private var isHookActionError: Bool = false

    private var thermalStateLabel: String {
        switch activityMonitor.lastThermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // MARK: - 1. Status Header & Quick Actions
            headerSection

            Divider()

            // MARK: - 2. Mascot Customization & Placement
            appearanceMenu
            positionMenu
            displayMenu

            Divider()

            // MARK: - 3. Sensors & AI Monitoring
            sensorsMenu
            agentsMenu

            Divider()

            // MARK: - 4. Diagnostics & Shortcuts Reference
            simulationMenu
            keybindsMenu

            Divider()

            // MARK: - 5. System, Updates & Lifecycle
            updatesMenu

            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLoginEnabled },
                set: { shouldEnable in
                    do {
                        if shouldEnable {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        launchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
                    } catch {
                        launchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
                    }
                }
            ))

            Divider()

            Button("Quit Bitz") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
    }

    // MARK: - Header & Primary Actions

    @ViewBuilder
    private var headerSection: some View {
        Text("Bitz the Cyber Cat")
            .font(.headline)
        Text("State: \(engine.currentState.rawValue) (\(String(format: "%.0f", engine.currentPoints)) PTS)")
        Text(String(format: "Streak: %.0f min • Focus: %.1f / 100", engine.continuousWorkMinutes, engine.currentPoints))
            .font(.caption)
            .foregroundStyle(.secondary)

        Button("Pet Bitz (<3)") {
            engine.triggerPetInteraction()
        }
        .accessibilityLabel("Pet Bitz")
        .keyboardShortcut("p")

        if positionStore.isPositionUnlocked {
            Button("✓ Lock Position [⎋ Esc / Right-Click]") {
                positionStore.lockPosition()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }

        if updateStore.isUpdateAvailable, let release = updateStore.latestRelease {
            Button("🚀 Download v\(release.semanticVersion.description)...") {
                updateStore.openDownloadPage()
            }
        }
    }

    // MARK: - Appearance Menu (Size & Opacity)

    @ViewBuilder
    private var appearanceMenu: some View {
        Menu("Appearance (Size & Opacity) 🎨") {
            Text("Avatar Size: \(scaleStore.formattedSizeSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Smaller (-10%)") {
                    scaleStore.stepDown()
                }
                .disabled(!scaleStore.canStepDown)
                .keyboardShortcut("-", modifiers: [.command])

                Button("Larger (+10%)") {
                    scaleStore.stepUp()
                }
                .disabled(!scaleStore.canStepUp)
                .keyboardShortcut("=", modifiers: [.command])
            }

            if !scaleStore.isPresetSelected(.defaultSize) {
                Button("Reset Size (100% — 250×250 pt)") {
                    scaleStore.resetToDefault()
                }
            }

            Menu("Size Presets (\(scaleStore.percentageInt)%)") {
                ForEach(AvatarSizePreset.allCases, id: \.rawValue) { preset in
                    Button(scaleStore.isPresetSelected(preset) ? "✓ \(preset.menuTitle)" : preset.menuTitle) {
                        scaleStore.selectPreset(preset)
                    }
                }
            }

            Divider()

            Text("Mascot Opacity: \(opacityStore.formattedOpacitySummary)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("More Transparent (-10%)") {
                    opacityStore.stepDown()
                }
                .disabled(!opacityStore.canStepDown)
                .keyboardShortcut("[", modifiers: [.command])

                Button("More Solid (+10%)") {
                    opacityStore.stepUp()
                }
                .disabled(!opacityStore.canStepUp)
                .keyboardShortcut("]", modifiers: [.command])
            }

            Menu("Opacity Presets (\(opacityStore.percentageInt)%)") {
                ForEach(AvatarOpacityPreset.allCases, id: \.rawValue) { preset in
                    Button(opacityStore.isPresetSelected(preset) ? "✓ \(preset.menuTitle)" : preset.menuTitle) {
                        opacityStore.selectPreset(preset)
                    }
                }
            }
        }
    }

    // MARK: - Position & Dragging Menu

    @ViewBuilder
    private var positionMenu: some View {
        Menu("Position & Dragging ✥") {
            Text("Mascot Position: \(positionStore.formattedPositionSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if positionStore.isPositionUnlocked {
                Button("✓ Lock Position [⎋ Esc / Right-Click]") {
                    positionStore.lockPosition()
                }
                .keyboardShortcut(.escape, modifiers: [])
            } else {
                Button("Unlock Position (Drag to Move)") {
                    positionStore.unlockPosition()
                }
            }

            Text("💡 Drag: Hold ⌥ Option anytime • Lock: ⎋ Esc or Right-Click")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            Menu("Screen Corner Presets") {
                ForEach(ScreenCornerAnchor.allCases, id: \.rawValue) { corner in
                    Button(positionStore.isCornerSelected(corner) ? "✓ \(corner.menuTitle)" : corner.menuTitle) {
                        positionStore.selectCorner(corner)
                    }
                }
            }

            if positionStore.isFreeform || positionStore.cornerAnchor != .bottomRight {
                Button("Reset to Default Corner (Bottom-Right)") {
                    positionStore.resetToDefaultCorner()
                }
            }
        }
    }

    // MARK: - Displays & Multi-Monitor Menu

    @ViewBuilder
    private var displayMenu: some View {
        Menu("Display: \(displayStore.summaryTitle) 🖥️") {
            Button(displayStore.targetMode == .primary ? "✓ Primary Screen" : "Primary Screen") {
                displayStore.selectMode(.primary)
            }

            Button(displayStore.targetMode == .followActive ? "✓ Follow Active Screen" : "Follow Active Screen") {
                displayStore.selectMode(.followActive)
            }

            Button(displayStore.targetMode == .allDisplays ? "✓ All Screens" : "All Screens") {
                displayStore.selectMode(.allDisplays)
            }

            if !displayStore.connectedScreens.isEmpty {
                Divider()
                Text("Connected Displays:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(displayStore.connectedScreens) { screen in
                    let isSelected = (displayStore.targetMode == .specific && displayStore.targetDisplayID == screen.id)
                    Button(isSelected ? "✓ \(screen.name)" : screen.name) {
                        displayStore.selectSpecificDisplay(id: screen.id, name: screen.name)
                    }
                }
            }
        }
    }

    // MARK: - Hardware & Activity Sensors Menu

    @ViewBuilder
    private var sensorsMenu: some View {
        Menu("Hardware & Sensors ⚡") {
            if let temp = activityMonitor.lastTemperatureCelsius {
                Text(String(format: "CPU Die Temp: %.1f °C (Warn > %.0f °C)", temp, activityMonitor.overheatingTemperatureThresholdCelsius))
            } else {
                Text("CPU Die Temp: Sensor Unavailable")
            }

            if let load = activityMonitor.lastCPULoadPercentage {
                Text(String(format: "CPU Load: %.1f%% (Warn > %.0f%%)", load, activityMonitor.overheatingCPULoadThresholdPercent))
            }

            Text("Thermal Pressure: \(thermalStateLabel)")

            let idleStatusSuffix: String = {
                if activityMonitor.isOnBreak {
                    return " (Charging ⚡)"
                } else if activityMonitor.lastIdleSeconds >= activityMonitor.idleBreakThresholdSeconds && activityMonitor.isWatchingMediaOrDistraction {
                    return " (Watching Media — Draining PTS)"
                } else {
                    return ""
                }
            }()
            Text(String(format: "User Idle: %.0fs%@", activityMonitor.lastIdleSeconds, idleStatusSuffix))

            if let appName = activityMonitor.lastFrontmostAppName {
                Divider()
                let tag = activityMonitor.lastAppIsProductive ? "+0.5 Productive" : "-1.5 Dopamine Drain"
                let customTag = activityMonitor.frontmostAppCustomRule.map { $0 ? " [Custom: Productive]" : " [Custom: Distraction]" } ?? ""
                Text("Active App: \(appName) (\(tag))\(customTag)")

                HStack(spacing: 6) {
                    if activityMonitor.frontmostAppCustomRule != true {
                        Button("Mark Productive") {
                            activityMonitor.markFrontmostApp(asProductive: true)
                        }
                    }
                    if activityMonitor.frontmostAppCustomRule != false {
                        Button("Mark Distraction") {
                            activityMonitor.markFrontmostApp(asProductive: false)
                        }
                    }
                    if activityMonitor.frontmostAppCustomRule != nil {
                        Button("Reset Rule") {
                            activityMonitor.resetFrontmostAppRule()
                        }
                    }
                }
            }

            Divider()

            Button("Sample Hardware Sensors Now") {
                activityMonitor.performSampleTick()
            }
        }
    }

    // MARK: - AI Coding Agents Menu

    @ViewBuilder
    private var agentsMenu: some View {
        Menu("AI Coding Agents (\(agentMonitor.activeAgents.count) Active) 🤖") {
            Toggle("Show Agent Status Popups", isOn: $agentMonitor.popupsEnabled)

            Divider()
            Text("Monitored Agents:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(agentMonitor.catalog) { agent in
                Toggle(agent.displayName, isOn: Binding(
                    get: { agent.isEnabled },
                    set: { isEnabled in
                        agentMonitor.setAgentEnabled(id: agent.id, isEnabled: isEnabled)
                    }
                ))
            }

            Divider()
            Menu("Claude Code Hooks") {
                Button("Install Hook to ~/.claude/settings.json") {
                    let url = URL(fileURLWithPath: ("~/.claude/settings.json" as NSString).expandingTildeInPath)
                    do {
                        try AgentHookInstaller.updateSettingsFile(at: url, AgentHookInstaller.installClaudeHooks)
                        hookActionMessage = "Claude Code hooks installed!"
                        isHookActionError = false
                    } catch {
                        hookActionMessage = "Failed to save hooks: \(error.localizedDescription)"
                        isHookActionError = true
                    }
                }

                Button("Uninstall Hook") {
                    let url = URL(fileURLWithPath: ("~/.claude/settings.json" as NSString).expandingTildeInPath)
                    do {
                        try AgentHookInstaller.updateSettingsFile(at: url, AgentHookInstaller.uninstallClaudeHooks)
                        hookActionMessage = "Claude Code hooks uninstalled."
                        isHookActionError = false
                    } catch {
                        hookActionMessage = "Failed to uninstall: \(error.localizedDescription)"
                        isHookActionError = true
                    }
                }
            }

            if let msg = hookActionMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(isHookActionError ? .red : .green)
            }
        }
    }

    // MARK: - State Simulation & Testing Menu

    @ViewBuilder
    private var simulationMenu: some View {
        Menu("State Simulation & Testing 🧪") {
            if activityMonitor.isManualOverrideActive {
                Button("Disable Override (Resume Live Sensors)") {
                    activityMonitor.clearManualOverride()
                }
                Divider()
            }

            Button("Super Charged (90 PTS - Magenta ^ ^)") {
                activityMonitor.isManualOverrideActive = true
                engine.setPoints(90.0, continuousWorkMinutes: 10.0)
            }
            .accessibilityLabel("Super Charged (90 PTS - Magenta)")

            Button("Balanced (50 PTS - Cyan)") {
                activityMonitor.isManualOverrideActive = true
                engine.setPoints(50.0, continuousWorkMinutes: 0.0)
            }

            Button("Sad / Dopamine Overload (20 PTS - Purple T T)") {
                activityMonitor.isManualOverrideActive = true
                engine.setPoints(20.0, continuousWorkMinutes: 0.0)
            }
            .accessibilityLabel("Sad or Dopamine Overload (20 PTS - Purple)")

            Button("Overworked (50m Non-Stop Work - Amber - -)") {
                activityMonitor.isManualOverrideActive = true
                engine.setPoints(75.0, continuousWorkMinutes: 50.0)
            }
            .accessibilityLabel("Overworked (50 minutes Non-Stop Work - Amber)")

            Button("Burnout (95m Non-Stop Work - X X)") {
                activityMonitor.isManualOverrideActive = true
                engine.setPoints(75.0, continuousWorkMinutes: 95.0)
            }
            .accessibilityLabel("Burnout (95 minutes Non-Stop Work)")

            Button("Charging Mode (Idle Away from Keyboard ⚡ Z Z)") {
                activityMonitor.isManualOverrideActive = true
                engine.setChargingState(true)
            }
            .accessibilityLabel("Charging Mode (Idle Away from Keyboard)")

            Button("Thermal / CPU Overheat (Cool-Down Action Alert)") {
                activityMonitor.isManualOverrideActive = true
                let temp = activityMonitor.lastTemperatureCelsius ?? 86.0
                let load = activityMonitor.lastCPULoadPercentage ?? 92.0
                engine.triggerThermalWarning(
                    isOverheating: true,
                    actionMessage: String(format: "🔥 %.0f°C (%.0f%% CPU) — CLOSE HEAVY TABS OR APPS TO COOL DOWN!", max(temp, 85.0), max(load, 88.0))
                )
            }
        }
    }

    // MARK: - Keybinds & Shortcuts Reference Menu

    @ViewBuilder
    private var keybindsMenu: some View {
        Menu("Keybinds & Shortcuts Reference ⌨️") {
            Text("MASCOT POSITIONING:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("• ⌥ Option + Drag — Move mascot anywhere anytime")
            Text("• ⎋ Escape or ⏎ Return — Lock position after moving")
            Text("• Right-Click on Mascot — Lock position immediately")
            Text("• Double-Click on Mascot — Lock position immediately")

            Divider()

            Text("SHORTCUTS:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("• P — Pet Bitz (<3)")
            Text("• ⌘ = / ⌘ - — Increase / Decrease size")
            Text("• ⌘ ] / ⌘ [ — Increase / Decrease opacity")
            Text("• ⎋ Esc — Lock position when unlocked")
            Text("• ⌘ Q — Quit Bitz")
        }
    }

    // MARK: - App Updates & Version Menu

    @ViewBuilder
    private var updatesMenu: some View {
        Menu("Updates & About (v\(updateStore.currentVersionString)) 🚀") {
            Text("Bitz v\(updateStore.currentVersionString)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if updateStore.isUpdateAvailable, let release = updateStore.latestRelease {
                Button("🚀 Download v\(release.semanticVersion.description)...") {
                    updateStore.openDownloadPage()
                }
                Button("View Release Notes...") {
                    updateStore.openReleaseNotes()
                }
                if updateStore.isSpeechBubbleAlertActive {
                    Button("Dismiss Alert Bubble") {
                        updateStore.dismissAlert()
                    }
                }
            } else {
                Button(updateStore.isChecking ? "Checking for Updates..." : "Check for Updates...") {
                    Task {
                        await updateStore.checkForUpdates(manual: true)
                    }
                }
                .disabled(updateStore.isChecking)

                if !updateStore.statusMessage.isEmpty && updateStore.statusMessage != "v\(updateStore.currentVersionString)" {
                    Text(updateStore.statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Toggle("Check for Updates Automatically", isOn: $updateStore.automaticallyCheckForUpdates)
        }
    }
}

/// SwiftUI `App` definition providing a lightweight Menu Bar status item for inspecting
/// Bitz's live hardware telemetry, wellness points, triggering `"Pet Bitz"`, and testing behavioral states (`FR-006`).
@MainActor
public struct BitzApp: App {
    @NSApplicationDelegateAdaptor(BitzAppDelegate.self) public var appDelegate

    public init() {}

    public var body: some Scene {
        MenuBarExtra("Bitz", systemImage: "cat.fill") {
            BitzMenuBarContentView(
                engine: appDelegate.engine,
                activityMonitor: appDelegate.activityMonitor,
                scaleStore: appDelegate.scaleStore,
                opacityStore: appDelegate.opacityStore,
                positionStore: appDelegate.positionStore,
                displayStore: appDelegate.displayStore,
                agentMonitor: appDelegate.agentMonitor,
                updateStore: appDelegate.updateStore
            )
        }
    }
}
