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
/// Bitz's wellness points and triggering the `"Pet Bitz"` interaction (`FR-006`).
@MainActor
public struct BitzApp: App {
    @NSApplicationDelegateAdaptor(BitzAppDelegate.self) public var appDelegate

    public init() {}

    public var body: some Scene {
        MenuBarExtra("Bitz", systemImage: "cat.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Bitz the Cyber Cat")
                    .font(.headline)
                Text("State: \(appDelegate.engine.currentState.rawValue)")
                Text(String(format: "Wellness: %.1f / 100", appDelegate.engine.currentPoints))
                Divider()
                Button("Pet Bitz") {
                    appDelegate.engine.triggerPetInteraction()
                }
            }
            .padding(8)
        }
    }
}
