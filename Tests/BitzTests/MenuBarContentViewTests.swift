import XCTest
import SwiftUI
@testable import BitzCore

@MainActor
final class MenuBarContentViewTests: XCTestCase {
    func testMenuBarContentViewCanBeInstantiatedWithStores() {
        let suiteName = "MenuBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

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

        let menuView = BitzMenuBarContentView(
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

        // Verify view body can be evaluated without crashing
        _ = menuView.body
        XCTAssertEqual(scaleStore.scaleFactor, 1.0)
        XCTAssertEqual(opacityStore.opacityFactor, 0.85, accuracy: 0.001)
        XCTAssertFalse(positionStore.isPositionUnlocked)
    }

    func testMenuBarContentViewReflectsUnlockedState() {
        let suiteName = "MenuBarUnlockedTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

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

        positionStore.unlockPosition()
        XCTAssertTrue(positionStore.isPositionUnlocked)

        let menuView = BitzMenuBarContentView(
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

        _ = menuView.body
        positionStore.lockPosition()
        XCTAssertFalse(positionStore.isPositionUnlocked)
    }
}
