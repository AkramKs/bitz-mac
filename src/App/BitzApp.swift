import AppKit
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
    public private(set) var overlayPanel: MascotOverlayPanel?

    public override convenience init() {
        self.init(
            riveController: ProductionRiveController(),
            telemetryProvider: SystemActivityTelemetryProvider(),
            scaleStore: AvatarScaleStore(),
            opacityStore: AvatarOpacityStore(),
            positionStore: AvatarPositionStore()
        )
    }

    public init(
        riveController: ProductionRiveController = ProductionRiveController(),
        telemetryProvider: ActivityTelemetryProviding = SystemActivityTelemetryProvider(),
        scaleStore: AvatarScaleStore = AvatarScaleStore(),
        opacityStore: AvatarOpacityStore = AvatarOpacityStore(),
        positionStore: AvatarPositionStore = AvatarPositionStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.riveController = riveController
        self.engine = WellnessPointEngine(riveController: riveController, userDefaults: userDefaults)
        self.activityMonitor = ActivityMonitorService(engine: self.engine, telemetry: telemetryProvider)
        self.scaleStore = scaleStore
        self.opacityStore = opacityStore
        self.positionStore = positionStore
        super.init()

        self.scaleStore.onScaleChanged = { [weak self] newScale in
            self?.overlayPanel?.applyScaleFactor(newScale)
        }
        self.positionStore.onCornerChanged = { [weak self] newCorner in
            self?.overlayPanel?.applyCornerAnchor(newCorner)
        }
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp?.setActivationPolicy(.accessory)
        setupOverlayPanel()
        activityMonitor.startMonitoring()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        activityMonitor.stopMonitoring()
        engine.persistState()
    }

    /// Instantiates and positions the borderless, click-through `MascotOverlayPanel`
    /// hosting `MascotOverlayView` at the user's persisted `scaleStore.scaleFactor`.
    public func setupOverlayPanel() {
        let panel = MascotOverlayPanel()
        let rootView = MascotOverlayView(engine: engine, scaleStore: scaleStore, opacityStore: opacityStore)
        let hostingView = NSHostingView(rootView: rootView)
        let initialSize = MascotOverlayPanel.calculatePanelSize(for: CGFloat(scaleStore.scaleFactor))
        hostingView.frame = NSRect(origin: .zero, size: initialSize)
        panel.contentView = hostingView
        panel.applyScaleFactor(CGFloat(scaleStore.scaleFactor))
        panel.applyCornerAnchor(positionStore.cornerAnchor)
        panel.repositionOnScreen()
        panel.orderFrontRegardless()
        self.overlayPanel = panel
    }
}

/// Observable Menu Bar content view displaying live hardware sensor telemetry,
/// wellness score, manual avatar resizing & opacity controls, and interactive state controls.
@MainActor
private struct BitzMenuBarContentView: View {
    @ObservedObject var engine: WellnessPointEngine
    @ObservedObject var activityMonitor: ActivityMonitorService
    @ObservedObject var scaleStore: AvatarScaleStore
    @ObservedObject var opacityStore: AvatarOpacityStore
    @ObservedObject var positionStore: AvatarPositionStore

    @AppStorage("enableManualStateOverrideMenu") private var showManualOverrideMenu: Bool = true
    @State private var launchAtLoginEnabled: Bool = (SMAppService.mainApp.status == .enabled)

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
            Text("Bitz the Cyber Cat")
                .font(.headline)
            Text("State: \(engine.currentState.rawValue)")
            Text(String(format: "Focus PTS: %.1f / 100", engine.currentPoints))
            Text(String(format: "Work Streak: %.1f min (Overwork >= 45m, Burnout >= 90m)", engine.continuousWorkMinutes))

            Divider()
            Text("Live Hardware & Activity Sensors")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let temp = activityMonitor.lastTemperatureCelsius {
                Text(String(format: "CPU Die Temp: %.1f °C (Warn > %.0f °C)", temp, activityMonitor.overheatingTemperatureThresholdCelsius))
            } else {
                Text("CPU Die Temp: Sensor Unavailable")
            }

            if let load = activityMonitor.lastCPULoadPercentage {
                Text(String(format: "CPU Load: %.1f%% (Warn > %.0f%%)", load, activityMonitor.overheatingCPULoadThresholdPercent))
            }

            Text("Thermal Pressure: \(thermalStateLabel)")

            if let appName = activityMonitor.lastFrontmostAppName {
                let tag = activityMonitor.lastAppIsProductive ? "+0.5 Productive" : "-1.5 Dopamine Drain"
                let customTag = activityMonitor.frontmostAppCustomRule.map { $0 ? " [Custom: Productive]" : " [Custom: Distraction]" } ?? ""
                Text("Active: \(appName) (\(tag))\(customTag)")

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

            Button("Sample Hardware Sensors Now") {
                activityMonitor.performSampleTick()
            }

            Divider()
            Button("Pet Bitz (<3)") {
                engine.triggerPetInteraction()
            }

            Divider()
            // See-Through / Opacity Controls
            Text("Mascot Opacity: \(opacityStore.formattedOpacitySummary)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("More Transparent (-10%)") {
                    opacityStore.stepDown()
                }
                .disabled(!opacityStore.canStepDown)

                Button("More Solid (+10%)") {
                    opacityStore.stepUp()
                }
                .disabled(!opacityStore.canStepUp)
            }

            Menu("Opacity Presets (\(opacityStore.percentageInt)%)") {
                ForEach(AvatarOpacityPreset.allCases, id: \.rawValue) { preset in
                    Button(opacityStore.isPresetSelected(preset) ? "✓ \(preset.menuTitle)" : preset.menuTitle) {
                        opacityStore.selectPreset(preset)
                    }
                }
            }

            Divider()
            // Avatar Resizing Controls
            Text("Avatar Size: \(scaleStore.formattedSizeSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Smaller (-10%)") {
                    scaleStore.stepDown()
                }
                .disabled(!scaleStore.canStepDown)

                Button("Larger (+10%)") {
                    scaleStore.stepUp()
                }
                .disabled(!scaleStore.canStepUp)
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
            // Corner Positioning Controls
            Menu("Screen Corner: \(positionStore.cornerAnchor.menuTitle)") {
                ForEach(ScreenCornerAnchor.allCases, id: \.rawValue) { corner in
                    Button(positionStore.isCornerSelected(corner) ? "✓ \(corner.menuTitle)" : corner.menuTitle) {
                        positionStore.selectCorner(corner)
                    }
                }
            }

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
            Toggle("Manual State Override", isOn: $showManualOverrideMenu)
                .onChange(of: showManualOverrideMenu) { _, isEnabled in
                    if !isEnabled {
                        activityMonitor.clearManualOverride()
                    }
                }

            if showManualOverrideMenu {
                if activityMonitor.isManualOverrideActive {
                    Button("Disable Override (Resume Live Sensors)") {
                        activityMonitor.clearManualOverride()
                    }
                }
                Button("Super Charged (90 PTS - Magenta ^ ^)") {
                    activityMonitor.isManualOverrideActive = true
                    engine.setPoints(90.0, continuousWorkMinutes: 10.0)
                }
                Button("Balanced (50 PTS - Cyan)") {
                    activityMonitor.isManualOverrideActive = true
                    engine.setPoints(50.0, continuousWorkMinutes: 0.0)
                }
                Button("Sad / Dopamine Overload (20 PTS - Purple T T)") {
                    activityMonitor.isManualOverrideActive = true
                    engine.setPoints(20.0, continuousWorkMinutes: 0.0)
                }
                Button("Overworked (50m Non-Stop Work - Amber - -)") {
                    activityMonitor.isManualOverrideActive = true
                    engine.setPoints(75.0, continuousWorkMinutes: 50.0)
                }
                Button("Burnout (95m Non-Stop Work - X X)") {
                    activityMonitor.isManualOverrideActive = true
                    engine.setPoints(75.0, continuousWorkMinutes: 95.0)
                }
                Button("Charging Mode (Idle Away from Keyboard ⚡ Z Z)") {
                    activityMonitor.isManualOverrideActive = true
                    engine.setChargingState(true)
                }
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
            Divider()
            Button("Quit Bitz") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
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
                positionStore: appDelegate.positionStore
            )
        }
    }
}
