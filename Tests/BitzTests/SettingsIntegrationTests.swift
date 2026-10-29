import AppKit
import SwiftUI
import XCTest
@testable import BitzCore

@MainActor
final class SettingsIntegrationTests: XCTestCase {

    override func tearDown() async throws {
        await MainActor.run {
            SettingsWindowManager.shared.closeSettingsWindow()
        }
        try await super.tearDown()
    }

    func testSettingsWindowCreationAndOverlayPanelInvariants() {
        let suiteName = "SettingsIntegrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        UserDefaults.standard.removeObject(forKey: "Bitz.AgentMonitor.PopupsEnabled")
        defer { UserDefaults.standard.removeObject(forKey: "Bitz.AgentMonitor.PopupsEnabled") }

        // 1. Set up Mascot Overlay Panel and verify baseline invariants
        let panel = MascotOverlayPanel()
        XCTAssertTrue(panel.ignoresMouseEvents, "Overlay panel must ignore mouse events by default")
        XCTAssertFalse(panel.canBecomeKey, "Overlay panel must never steal keyboard focus")
        XCTAssertFalse(panel.canBecomeMain, "Overlay panel must never become main window")
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel), "Overlay panel must be non-activating")

        // 2. Set up Stores & Dependencies
        let riveController = ProductionRiveController()
        let engine = WellnessPointEngine(riveController: riveController, userDefaults: defaults)
        let telemetry = MockTelemetryProvider()
        let activityMonitor = ActivityMonitorService(engine: engine, telemetry: telemetry)
        let scaleStore = AvatarScaleStore(userDefaults: defaults)
        let opacityStore = AvatarOpacityStore(userDefaults: defaults)
        let positionStore = AvatarPositionStore(userDefaults: defaults)
        let displayStore = DisplayPreferenceStore(userDefaults: defaults)
        let agentMonitor = AgentMonitorService(adapters: [])
        let updateStore = AppUpdateStore(userDefaults: defaults)
        let telemetrySettings = TelemetrySettingsStore(userDefaults: defaults)
        let telemetryDashboard = TelemetryDashboardService(settingsStore: telemetrySettings)

        let rootView = SettingsRootView(
            engine: engine,
            activityMonitor: activityMonitor,
            scaleStore: scaleStore,
            opacityStore: opacityStore,
            positionStore: positionStore,
            displayStore: displayStore,
            agentMonitor: agentMonitor,
            updateStore: updateStore,
            telemetryDashboard: telemetryDashboard,
            telemetrySettings: telemetrySettings
        )

        // 3. Open Settings Window via SettingsWindowManager
        SettingsWindowManager.shared.showSettingsWindow(rootView: rootView)

        XCTAssertTrue(SettingsWindowManager.shared.isWindowOpen, "Settings window must be marked open")
        guard let window = SettingsWindowManager.shared.window else {
            XCTFail("Settings window must be created")
            return
        }

        XCTAssertTrue(window.styleMask.contains(.titled), "Settings window must be titled")
        XCTAssertTrue(window.styleMask.contains(.closable), "Settings window must be closable")
        XCTAssertTrue(window.styleMask.contains(.miniaturizable), "Settings window must be miniaturizable")
        XCTAssertEqual(window.title, "Bitz Settings", "Settings window title must match")
        XCTAssertTrue(window.canBecomeKey, "Settings window can become key for user interactions")

        // 4. Invariant Assertion: MascotOverlayPanel invariants are completely unaffected
        XCTAssertTrue(panel.ignoresMouseEvents, "Overlay panel must remain click-through while settings window is open")
        XCTAssertFalse(panel.canBecomeKey, "Overlay panel must never steal key window state")
        XCTAssertFalse(panel.canBecomeMain, "Overlay panel must never become main window")

        // 5. Simulate settings modification (e.g. scale change)
        scaleStore.stepUp()
        XCTAssertEqual(scaleStore.scaleFactor, 1.10, accuracy: 0.001)

        // Overlay invariants still preserved
        XCTAssertTrue(panel.ignoresMouseEvents, "Overlay panel ignoresMouseEvents must stay true after setting mutations")
        XCTAssertFalse(panel.canBecomeKey)

        // 6. Close Settings Window
        SettingsWindowManager.shared.closeSettingsWindow()
        XCTAssertFalse(SettingsWindowManager.shared.isWindowOpen, "Settings window must be marked closed")
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.canBecomeKey)
    }

    func testSettingsWindowReopenReusesExistingWindowInstance() {
        let suiteName = "SettingsReopenTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        UserDefaults.standard.removeObject(forKey: "Bitz.AgentMonitor.PopupsEnabled")
        defer { UserDefaults.standard.removeObject(forKey: "Bitz.AgentMonitor.PopupsEnabled") }

        let riveController = ProductionRiveController()
        let engine = WellnessPointEngine(riveController: riveController, userDefaults: defaults)
        let telemetry = MockTelemetryProvider()
        let activityMonitor = ActivityMonitorService(engine: engine, telemetry: telemetry)
        let scaleStore = AvatarScaleStore(userDefaults: defaults)
        let opacityStore = AvatarOpacityStore(userDefaults: defaults)
        let positionStore = AvatarPositionStore(userDefaults: defaults)
        let displayStore = DisplayPreferenceStore(userDefaults: defaults)
        let agentMonitor = AgentMonitorService(adapters: [])
        let updateStore = AppUpdateStore(userDefaults: defaults)
        let telemetrySettings = TelemetrySettingsStore(userDefaults: defaults)
        let telemetryDashboard = TelemetryDashboardService(settingsStore: telemetrySettings)

        let rootView = SettingsRootView(
            engine: engine,
            activityMonitor: activityMonitor,
            scaleStore: scaleStore,
            opacityStore: opacityStore,
            positionStore: positionStore,
            displayStore: displayStore,
            agentMonitor: agentMonitor,
            updateStore: updateStore,
            telemetryDashboard: telemetryDashboard,
            telemetrySettings: telemetrySettings
        )

        // First open
        SettingsWindowManager.shared.showSettingsWindow(rootView: rootView)
        let firstWindow = SettingsWindowManager.shared.window
        XCTAssertNotNil(firstWindow)

        // Second call while open should reuse the same window
        SettingsWindowManager.shared.showSettingsWindow(rootView: rootView)
        let secondWindow = SettingsWindowManager.shared.window
        XCTAssertTrue(firstWindow === secondWindow, "Same window instance must be reused")

        // Close
        SettingsWindowManager.shared.closeSettingsWindow()
        XCTAssertFalse(SettingsWindowManager.shared.isWindowOpen)
    }
}
