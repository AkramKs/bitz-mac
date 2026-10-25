import XCTest
@testable import BitzCore

@MainActor
final class MockTelemetryProvider: ActivityTelemetryProviding {
    var bundleID: String? = "com.apple.dt.Xcode"
    var idleSeconds: TimeInterval = 0.0
    var currentThermalState: ProcessInfo.ThermalState = .nominal
    var currentTemperatureCelsius: Double? = 45.0
    var currentDate: Date = Date(timeIntervalSince1970: 1_700_000_000)

    func frontmostBundleIdentifier() -> String? {
        bundleID
    }

    func secondsSinceLastInput() -> TimeInterval {
        idleSeconds
    }

    func thermalState() -> ProcessInfo.ThermalState {
        currentThermalState
    }

    func cpuTemperatureCelsius() -> Double? {
        currentTemperatureCelsius
    }

    func now() -> Date {
        currentDate
    }
}

@MainActor
final class ActivityMonitorServiceTests: XCTestCase {

    func testProductiveBundleIDClassification() {
        let engine = WellnessPointEngine()
        let telemetry = MockTelemetryProvider()
        let service = ActivityMonitorService(engine: engine, telemetry: telemetry)

        XCTAssertTrue(service.isProductiveBundleID("com.apple.dt.Xcode"))
        XCTAssertTrue(service.isProductiveBundleID("com.microsoft.VSCode"))
        XCTAssertTrue(service.isProductiveBundleID("com.apple.Terminal"))
        XCTAssertTrue(service.isProductiveBundleID("com.googlecode.iterm2"))
        XCTAssertTrue(service.isProductiveBundleID("com.todesktop.230313mzl4w4u92"))
        XCTAssertTrue(service.isProductiveBundleID("dev.warp.Warp-Stable"))
        XCTAssertTrue(service.isProductiveBundleID("com.jetbrains.intellij"))
        XCTAssertTrue(service.isProductiveBundleID("com.google.antigravity"))
        XCTAssertTrue(service.isProductiveBundleID("com.google.antigravity-ide"))
        XCTAssertTrue(service.isProductiveBundleID("com.microsoft.Word"))
        XCTAssertTrue(service.isProductiveBundleID("com.microsoft.Excel"))
        XCTAssertTrue(service.isProductiveBundleID("com.microsoft.Powerpoint"))
        XCTAssertTrue(service.isProductiveBundleID("com.microsoft.Outlook"))
        XCTAssertTrue(service.isProductiveBundleID("com.microsoft.teams2"))
        XCTAssertTrue(service.isProductiveBundleID("com.tinyspeck.slackmacgap"))
        XCTAssertTrue(service.isProductiveBundleID("notion.id"))
        XCTAssertTrue(service.isProductiveBundleID("com.figma.Desktop"))

        XCTAssertFalse(service.isProductiveBundleID("com.apple.Safari"))
        XCTAssertFalse(service.isProductiveBundleID("org.mozilla.firefox"))
        XCTAssertFalse(service.isProductiveBundleID(nil))
    }

    func testProductiveAndUnproductiveSampleTicksUpdateWellnessEngine() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 50.0, riveController: spy)
        let telemetry = MockTelemetryProvider()
        let service = ActivityMonitorService(engine: engine, telemetry: telemetry)

        // Productive app tick -> +0.5
        telemetry.bundleID = "com.apple.dt.Xcode"
        service.performSampleTick()
        XCTAssertEqual(engine.currentPoints, 50.5, accuracy: 0.0001)

        // Unproductive app tick -> -1.5
        telemetry.bundleID = "com.apple.Safari"
        service.performSampleTick()
        XCTAssertEqual(engine.currentPoints, 49.0, accuracy: 0.0001)
    }

    func testIdleBreakEntryAndShortBreakRecoveryBelowTenMinutes() {
        let engine = WellnessPointEngine(initialPoints: 30.0)
        let telemetry = MockTelemetryProvider()
        let service = ActivityMonitorService(
            engine: engine,
            telemetry: telemetry,
            idleBreakThresholdSeconds: 60.0
        )

        // User becomes idle for 65 seconds -> enters break, does not penalize points
        telemetry.bundleID = "com.apple.Safari"
        telemetry.idleSeconds = 65.0
        service.performSampleTick()
        XCTAssertTrue(service.isOnBreak)
        XCTAssertNotNil(service.breakStartedAt)
        XCTAssertEqual(engine.currentPoints, 30.0, accuracy: 0.0001)

        // User remains idle for 5 minutes total -> still on break
        telemetry.currentDate = telemetry.currentDate.addingTimeInterval(235.0)
        telemetry.idleSeconds = 300.0
        service.performSampleTick()
        XCTAssertTrue(service.isOnBreak)
        XCTAssertEqual(engine.currentPoints, 30.0, accuracy: 0.0001)

        // User returns after 5 minutes (<= 10.0 min) in Xcode -> 0 break bonus, +0.5 work tick
        telemetry.bundleID = "com.apple.dt.Xcode"
        telemetry.idleSeconds = 0.0
        service.performSampleTick()
        XCTAssertFalse(service.isOnBreak)
        XCTAssertNil(service.breakStartedAt)
        XCTAssertEqual(engine.currentPoints, 30.5, accuracy: 0.0001)
    }

    func testLongOfflineBreakGreaterThanTenMinutesRestoresWellnessPoints() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 12.0, riveController: spy)
        XCTAssertEqual(engine.currentState, .burnout)

        let telemetry = MockTelemetryProvider()
        let service = ActivityMonitorService(
            engine: engine,
            telemetry: telemetry,
            idleBreakThresholdSeconds: 60.0
        )

        // Enter break at t=0 (already idle for 60s, so breakStartedAt = t - 60s)
        telemetry.idleSeconds = 60.0
        service.performSampleTick()
        XCTAssertTrue(service.isOnBreak)

        // Advance clock by 11 minutes (660s) -> total break duration = 12 minutes (> 10.0)
        telemetry.currentDate = telemetry.currentDate.addingTimeInterval(660.0)
        telemetry.idleSeconds = 0.0
        telemetry.bundleID = "com.apple.dt.Xcode"

        // Return from break: +60.0 break pts (12.0 + 60.0 = 72.0) + 0.5 work tick = 72.5 (.balanced)
        service.performSampleTick()
        XCTAssertFalse(service.isOnBreak)
        XCTAssertEqual(engine.currentPoints, 72.5, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .balanced)
        XCTAssertEqual(spy.floatInputs["visorColor"], 0.0)
        XCTAssertEqual(spy.boolInputs["isStandby"], false)
    }

    func testThermalOverheatingByTemperatureAndThermalStateAndRecovery() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 60.0, riveController: spy)
        let telemetry = MockTelemetryProvider()
        let service = ActivityMonitorService(engine: engine, telemetry: telemetry)

        // 1. Spike CPU temperature > 80.0C
        telemetry.currentTemperatureCelsius = 85.0
        service.performSampleTick()
        XCTAssertTrue(service.isOverheatingActive)
        XCTAssertEqual(engine.currentState, .overheating)
        XCTAssertEqual(engine.activeSpeechBubbleText, "SYSTEM HOT! > <")
        XCTAssertEqual(spy.floatInputs["visorColor"], 3.0)
        XCTAssertEqual(spy.boolInputs["isGlitching"], true)

        // 2. Cool CPU temperature to 55.0C, nominal thermalState -> restores .balanced
        telemetry.currentTemperatureCelsius = 55.0
        telemetry.currentThermalState = .nominal
        service.performSampleTick()
        XCTAssertFalse(service.isOverheatingActive)
        XCTAssertEqual(engine.currentState, .balanced)
        XCTAssertNil(engine.activeSpeechBubbleText)

        // 3. Spike ProcessInfo.ThermalState to .critical even with nil temperature
        telemetry.currentTemperatureCelsius = nil
        telemetry.currentThermalState = .critical
        service.performSampleTick()
        XCTAssertTrue(service.isOverheatingActive)
        XCTAssertEqual(engine.currentState, .overheating)
    }

    func testStartAndStopMonitoringLifecycleAndSystemProvider() {
        let engine = WellnessPointEngine()
        let systemProvider = SystemActivityTelemetryProvider()
        _ = systemProvider.frontmostBundleIdentifier()
        _ = systemProvider.frontmostApplicationName()
        XCTAssertGreaterThanOrEqual(systemProvider.secondsSinceLastInput(), 0.0)
        _ = systemProvider.thermalState()
        if let temp = systemProvider.cpuTemperatureCelsius() {
            XCTAssertGreaterThan(temp, 15.0)
            XCTAssertLessThan(temp, 130.0)
        }
        if let load = systemProvider.cpuLoadPercentage() {
            XCTAssertGreaterThanOrEqual(load, 0.0)
            XCTAssertLessThanOrEqual(load, 100.0)
        }
        XCTAssertNotNil(systemProvider.now())

        let service = ActivityMonitorService(engine: engine, telemetry: systemProvider)
        XCTAssertFalse(service.isMonitoring)

        service.startMonitoring(intervalSeconds: 10.0)
        XCTAssertTrue(service.isMonitoring)

        service.stopMonitoring()
        XCTAssertFalse(service.isMonitoring)
    }
}
