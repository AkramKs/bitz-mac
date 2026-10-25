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

/// SwiftUI `App` definition providing a lightweight Menu Bar status item for inspecting
/// Bitz's wellness points, triggering `"Pet Bitz"`, and testing behavioral states (`FR-006`).
@MainActor
public struct BitzApp: App {
    @NSApplicationDelegateAdaptor(BitzAppDelegate.self) public var appDelegate

    public init() {}

    public var body: some Scene {
        MenuBarExtra("Bitz", systemImage: "cat.fill") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bitz the Cyber Cat")
                    .font(.headline)
                Text("State: \(appDelegate.engine.currentState.rawValue)")
                Text(String(format: "Wellness: %.1f / 100", appDelegate.engine.currentPoints))
                Divider()
                Button("Pet Bitz (<3)") {
                    appDelegate.engine.triggerPetInteraction()
                }
                Divider()
                Text("Preview States")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Super Charged (90 pts - Magenta)") {
                    appDelegate.engine.setPoints(90.0)
                }
                Button("Balanced (50 pts - Cyan)") {
                    appDelegate.engine.setPoints(50.0)
                }
                Button("Overworked (25 pts - Amber)") {
                    appDelegate.engine.setPoints(25.0)
                }
                Button("Burnout / Standby (10 pts - ZZZ)") {
                    appDelegate.engine.setPoints(10.0)
                }
                Button("Thermal Overheat (SYSTEM HOT!)") {
                    appDelegate.engine.triggerThermalWarning(isOverheating: true)
                }
                Divider()
                Button("Quit Bitz") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(8)
        }
    }
}
