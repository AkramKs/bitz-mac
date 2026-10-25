import AppKit
import SwiftUI

/// Application delegate managing the transparent `MascotOverlayPanel`, `WellnessPointEngine`,
/// and `ActivityMonitorService` lifecycle (`FR-001`, `FR-005`, `FR-006`).
@MainActor
public final class BitzAppDelegate: NSObject, NSApplicationDelegate {
    public let riveController: ProductionRiveController
    public let engine: WellnessPointEngine
    public let activityMonitor: ActivityMonitorService
    public private(set) var overlayPanel: MascotOverlayPanel?

    public override convenience init() {
        self.init(
            riveController: ProductionRiveController(),
            telemetryProvider: SystemActivityTelemetryProvider()
        )
    }

    public init(
        riveController: ProductionRiveController = ProductionRiveController(),
        telemetryProvider: ActivityTelemetryProviding = SystemActivityTelemetryProvider()
    ) {
        self.riveController = riveController
        self.engine = WellnessPointEngine(initialPoints: 50.0, riveController: riveController)
        self.activityMonitor = ActivityMonitorService(engine: self.engine, telemetry: telemetryProvider)
        super.init()
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
    /// hosting `MascotOverlayView`.
    public func setupOverlayPanel() {
        let panel = MascotOverlayPanel()
        let rootView = MascotOverlayView(engine: engine)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: MascotOverlayPanel.defaultPanelSize)
        panel.contentView = hostingView
        panel.positionInBottomRight()
        panel.orderFrontRegardless()
        self.overlayPanel = panel
    }
}

/// Observable Menu Bar content view displaying live hardware sensor telemetry,
/// wellness score, and interactive state controls.
@MainActor
private struct BitzMenuBarContentView: View {
    @ObservedObject var engine: WellnessPointEngine
    @ObservedObject var activityMonitor: ActivityMonitorService
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

            Text(String(format: "User Idle: %.0fs%@", activityMonitor.lastIdleSeconds, activityMonitor.isOnBreak ? " (Charging ⚡)" : ""))

            Button("Sample Hardware Sensors Now") {
                activityMonitor.performSampleTick()
            }

            Divider()
            Button("Pet Bitz (<3)") {
                engine.triggerPetInteraction()
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
                activityMonitor: appDelegate.activityMonitor
            )
        }
    }
}
