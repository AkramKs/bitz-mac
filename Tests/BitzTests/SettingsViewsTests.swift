import XCTest
import SwiftUI
@testable import BitzCore

@MainActor
final class SettingsViewsTests: XCTestCase {
    func testSettingsRootViewAndTabsCanBeInstantiated() {
        let suiteName = "SettingsViewsTests.\(UUID().uuidString)"
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

        // Verify body evaluation
        _ = rootView.body

        // Verify General Tab interactions
        scaleStore.stepUp()
        XCTAssertEqual(scaleStore.scaleFactor, 1.10, accuracy: 0.001)

        opacityStore.stepDown()
        XCTAssertEqual(opacityStore.opacityFactor, 0.75, accuracy: 0.001)

        positionStore.unlockPosition()
        XCTAssertTrue(positionStore.isPositionUnlocked)
        positionStore.lockPosition()
        XCTAssertFalse(positionStore.isPositionUnlocked)

        // Verify Agent Tab interactions
        XCTAssertTrue(agentMonitor.popupsEnabled)
        agentMonitor.popupsEnabled = false
        XCTAssertFalse(agentMonitor.popupsEnabled)

        // Verify Telemetry Tab interactions
        XCTAssertTrue(telemetrySettings.isMetricEnabled(.ram))
        telemetrySettings.setMetric(.ram, enabled: false)
        XCTAssertFalse(telemetrySettings.isMetricEnabled(.ram))

        // Verify Behavior State override
        activityMonitor.isManualOverrideActive = true
        engine.setPoints(90.0, continuousWorkMinutes: 10.0)
        XCTAssertEqual(engine.currentPoints, 90.0)
    }

    func testGeneralSettingsTabViewInteractions() {
        let suiteName = "GeneralSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let scaleStore = AvatarScaleStore(userDefaults: defaults)
        let opacityStore = AvatarOpacityStore(userDefaults: defaults)
        let positionStore = AvatarPositionStore(userDefaults: defaults)
        let displayStore = DisplayPreferenceStore(userDefaults: defaults)

        let tab = GeneralSettingsTabView(
            scaleStore: scaleStore,
            opacityStore: opacityStore,
            positionStore: positionStore,
            displayStore: displayStore
        )

        _ = tab.body

        scaleStore.selectPreset(.medium)
        XCTAssertEqual(scaleStore.scaleFactor, 0.80, accuracy: 0.001)

        opacityStore.selectPreset(.ghost)
        XCTAssertEqual(opacityStore.opacityFactor, 0.40, accuracy: 0.001)

        displayStore.selectMode(.followActive)
        XCTAssertEqual(displayStore.targetMode, .followActive)
    }

    func testBitzCharacterViewAndRealMascotPreview() {
        for state in BitzState.allCases {
            let characterView = BitzCharacterView(state: state)
            _ = characterView.body

            let rgb = BitzCharacterView.visorRGB(for: state)
            let mascotRGB = MascotOverlayView.visorRGB(for: state)
            XCTAssertEqual(rgb.red, mascotRGB.red, accuracy: 0.001)
            XCTAssertEqual(rgb.green, mascotRGB.green, accuracy: 0.001)
            XCTAssertEqual(rgb.blue, mascotRGB.blue, accuracy: 0.001)
        }

        let animatedView = AnimatedBitzCharacterView(state: .balanced, showParticles: true)
        _ = animatedView.body

        let suiteName = "RealMascotPreviewTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let riveController = ProductionRiveController()
        let engine = WellnessPointEngine(riveController: riveController, userDefaults: defaults)
        let scaleStore = AvatarScaleStore(userDefaults: defaults)
        let opacityStore = AvatarOpacityStore(userDefaults: defaults)
        let positionStore = AvatarPositionStore(userDefaults: defaults)
        let displayStore = DisplayPreferenceStore(userDefaults: defaults)

        let tabWithEngine = GeneralSettingsTabView(
            scaleStore: scaleStore,
            opacityStore: opacityStore,
            positionStore: positionStore,
            displayStore: displayStore,
            engine: engine
        )
        _ = tabWithEngine.body
    }
}
