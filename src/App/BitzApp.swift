import AppKit
import SwiftUI

/// Application delegate managing the transparent `MascotOverlayPanel`, `WellnessPointEngine`,
/// `ActivityMonitorService`, and `AvatarScaleStore` lifecycle (`FR-001`, `FR-005`, `FR-006`).
@MainActor
public final class BitzAppDelegate: NSObject, NSApplicationDelegate {
    public let riveController: ProductionRiveController
    public let engine: WellnessPointEngine
    public let activityMonitor: ActivityMonitorService
    public let scaleStore: AvatarScaleStore
    public private(set) var overlayPanel: MascotOverlayPanel?

    public override convenience init() {
        self.init(
            riveController: ProductionRiveController(),
            telemetryProvider: SystemActivityTelemetryProvider(),
            scaleStore: AvatarScaleStore()
        )
    }

    public init(
        riveController: ProductionRiveController = ProductionRiveController(),
        telemetryProvider: ActivityTelemetryProviding = SystemActivityTelemetryProvider(),
        scaleStore: AvatarScaleStore = AvatarScaleStore()
    ) {
        self.riveController = riveController
        self.engine = WellnessPointEngine(initialPoints: 50.0, riveController: riveController)
        self.activityMonitor = ActivityMonitorService(engine: self.engine, telemetry: telemetryProvider)
        self.scaleStore = scaleStore
        super.init()

        self.scaleStore.onScaleChanged = { [weak self] newScale in
            self?.overlayPanel?.applyScaleFactor(newScale)
        }
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp?.setActivationPolicy(.accessory)
        setupOverlayPanel()
        activityMonitor.startMonitoring()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        activityMonitor.stopMonitoring()
    }

    /// Instantiates and positions the borderless, click-through `MascotOverlayPanel`
    /// hosting `MascotOverlayView` at the user's persisted `scaleStore.scaleFactor`.
    public func setupOverlayPanel() {
        let panel = MascotOverlayPanel()
        let rootView = MascotOverlayView(engine: engine, scaleStore: scaleStore)
        let hostingView = NSHostingView(rootView: rootView)
        let initialSize = MascotOverlayPanel.calculatePanelSize(for: CGFloat(scaleStore.scaleFactor))
        hostingView.frame = NSRect(origin: .zero, size: initialSize)
        panel.contentView = hostingView
        panel.applyScaleFactor(CGFloat(scaleStore.scaleFactor))
        panel.orderFrontRegardless()
        self.overlayPanel = panel
    }
}

/// Observable Menu Bar content view displaying live hardware sensor telemetry,
/// wellness score, manual avatar resizing controls, and interactive state controls.
@MainActor
private struct BitzMenuBarContentView: View {
    @ObservedObject var engine: WellnessPointEngine
    @ObservedObject var activityMonitor: ActivityMonitorService
    @ObservedObject var scaleStore: AvatarScaleStore
    @AppStorage("enableManualStateOverrideMenu") private var showManualOverrideMenu: Bool = true

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
                Text("Active App: \(appName) (\(tag))")
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
            Text("Avatar Size: \(scaleStore.formattedSizeSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Smaller (-10%)") {
                scaleStore.stepDown()
            }
            .disabled(!scaleStore.canStepDown)

            Button("Larger (+10%)") {
                scaleStore.stepUp()
            }
            .disabled(!scaleStore.canStepUp)

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
                scaleStore: appDelegate.scaleStore
            )
        }
    }
}
