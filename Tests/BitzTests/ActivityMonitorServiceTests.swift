import XCTest
@testable import BitzCore

@MainActor
final class MockTelemetryProvider: ActivityTelemetryProviding {
    var bundleID: String? = "com.apple.dt.Xcode"
    var tabURL: String? = nil
    var tabTitle: String? = nil
    var videoPlaying: Bool = false
    var idleSeconds: TimeInterval = 0.0
    var currentThermalState: ProcessInfo.ThermalState = .nominal
    var currentTemperatureCelsius: Double? = 45.0
    var currentDate: Date = Date(timeIntervalSince1970: 1_700_000_000)

    func frontmostBundleIdentifier() -> String? {
        bundleID
    }

    func activeBrowserTabURL() -> String? {
        tabURL
    }

    func activeBrowserTabTitle() -> String? {
        tabTitle
    }

    func isVideoPlaybackActive() -> Bool {
        videoPlaying
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

        // Browser on GitHub / Docs -> Productive (+0.5 PTS)
        XCTAssertTrue(
            service.isProductiveBundleID(
                "org.mozilla.firefox",
                activeTabURL: "https://github.com/AkramKs/bitz-mac",
                activeTabTitle: "AkramKs/bitz-mac"
            )
        )

        // Browser on Streaming / Social Media -> Dopamine Drain (-1.5 PTS)
        XCTAssertFalse(
            service.isProductiveBundleID(
                "org.mozilla.firefox",
                activeTabURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                activeTabTitle: "YouTube"
            )
        )
        XCTAssertFalse(
            service.isProductiveBundleID(
                "org.mozilla.firefox",
                activeTabURL: "https://www.netflix.com/browse",
                activeTabTitle: "Netflix"
            )
        )
        XCTAssertFalse(
            service.isProductiveBundleID(
                "org.mozilla.firefox",
                activeTabURL: "https://www.instagram.com/",
                activeTabTitle: "Instagram"
            )
        )
        XCTAssertFalse(
            service.isProductiveBundleID(
                "org.mozilla.firefox",
                activeTabURL: "https://www.facebook.com/",
                activeTabTitle: "Facebook"
            )
        )

        XCTAssertFalse(service.isProductiveBundleID("com.apple.Safari"))
        XCTAssertFalse(service.isProductiveBundleID("net.whatsapp.WhatsApp"))
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

    func testIdleBreakEntryEntersChargingModeAndRecovers() {
        let engine = WellnessPointEngine(initialPoints: 30.0)
        let telemetry = MockTelemetryProvider()
        let service = ActivityMonitorService(
            engine: engine,
            telemetry: telemetry,
            idleBreakThresholdSeconds: 60.0
        )

        // User becomes idle for 65 seconds -> enters .charging (+0.5 PTS per idle tick)
        telemetry.bundleID = "com.apple.Safari"
        telemetry.idleSeconds = 65.0
        service.performSampleTick()
        XCTAssertTrue(service.isOnBreak)
        XCTAssertEqual(engine.currentState, .charging)
        XCTAssertEqual(engine.currentPoints, 30.5, accuracy: 0.0001)

        // User remains idle for another tick -> continues charging (+0.5 PTS)
        telemetry.currentDate = telemetry.currentDate.addingTimeInterval(30.0)
        telemetry.idleSeconds = 95.0
        service.performSampleTick()
        XCTAssertTrue(service.isOnBreak)
        XCTAssertEqual(engine.currentState, .charging)
        XCTAssertEqual(engine.currentPoints, 31.0, accuracy: 0.0001)

        // User returns after 95s (<= 2.0 min) in Xcode -> exits .charging, +0.5 work tick
        telemetry.bundleID = "com.apple.dt.Xcode"
        telemetry.idleSeconds = 0.0
        service.performSampleTick()
        XCTAssertFalse(service.isOnBreak)
        XCTAssertNil(service.breakStartedAt)
        XCTAssertEqual(engine.currentPoints, 31.5, accuracy: 0.0001)
    }

    func testLongOfflineBreakRestoresWellnessPointsAndClearsBurnout() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 12.0, initialContinuousWorkMinutes: 95.0, riveController: spy)
        XCTAssertEqual(engine.currentState, .burnout)

        let telemetry = MockTelemetryProvider()
        let service = ActivityMonitorService(
            engine: engine,
            telemetry: telemetry,
            idleBreakThresholdSeconds: 60.0
        )

        // Enter break at t=0 (idle for 60s -> .charging, 12.5 pts)
        telemetry.idleSeconds = 60.0
        service.performSampleTick()
        XCTAssertTrue(service.isOnBreak)
        XCTAssertEqual(engine.currentState, .charging)

        // Advance clock by 11 minutes (660s) -> total break duration = 12 minutes (> 2.0m)
        telemetry.currentDate = telemetry.currentDate.addingTimeInterval(660.0)
        telemetry.idleSeconds = 0.0
        telemetry.bundleID = "com.apple.dt.Xcode"

        // Return from break: +60.0 break pts (12.5 + 60.0 = 72.5) + 0.5 work tick = 73.0 (.balanced)
        service.performSampleTick()
        XCTAssertFalse(service.isOnBreak)
        XCTAssertEqual(engine.currentPoints, 73.0, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .balanced)
        XCTAssertEqual(spy.floatInputs["visorColor"], 0.0)
        XCTAssertEqual(spy.boolInputs["isStandby"], false)
    }

    func testWatchingYouTubeOrNetflixHandsFreeDoesNotEnterChargeModeAndContinuesDrainingPoints() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 42.0, riveController: spy)
        let telemetry = MockTelemetryProvider()
        let service = ActivityMonitorService(
            engine: engine,
            telemetry: telemetry,
            idleBreakThresholdSeconds: 60.0
        )

        // 1. User opens YouTube (or Netflix) and starts watching -> drains -1.5 PTS while idleSeconds < 60
        telemetry.bundleID = "org.mozilla.firefox"
        telemetry.tabURL = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        telemetry.tabTitle = "YouTube"
        telemetry.idleSeconds = 10.0
        service.performSampleTick()
        XCTAssertFalse(service.isOnBreak)
        XCTAssertTrue(service.isWatchingMediaOrDistraction)
        XCTAssertEqual(engine.currentPoints, 40.5, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .balanced)

        // 2. User stops moving mouse for > 60s (e.g. 65s, 300s, 1800s) while watching YouTube / Netflix:
        // Must NOT enter .charging mode! Must keep draining -1.5 PTS per tick into .dopamineSad!
        telemetry.currentDate = telemetry.currentDate.addingTimeInterval(55.0)
        telemetry.idleSeconds = 65.0
        service.performSampleTick()
        XCTAssertFalse(service.isOnBreak)
        XCTAssertNil(service.breakStartedAt)
        XCTAssertEqual(engine.currentPoints, 39.0, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .dopamineSad)
        XCTAssertEqual(engine.activeSpeechBubbleText, WellnessPointEngine.dopamineSadText)

        // 3. User switches to a film on Netflix and watches for 20 minutes hands-free without moving mouse
        telemetry.tabURL = "https://www.netflix.com/watch/80057281"
        telemetry.tabTitle = "Netflix"
        telemetry.currentDate = telemetry.currentDate.addingTimeInterval(1200.0)
        telemetry.idleSeconds = 1265.0
        service.performSampleTick()
        XCTAssertFalse(service.isOnBreak)
        XCTAssertNil(service.breakStartedAt)
        XCTAssertEqual(engine.currentPoints, 37.5, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .dopamineSad)

        // 4. When user finally moves mouse and returns to Xcode, no fake offline break points are awarded
        telemetry.bundleID = "com.apple.dt.Xcode"
        telemetry.tabURL = nil
        telemetry.tabTitle = nil
        telemetry.idleSeconds = 0.0
        service.performSampleTick()
        XCTAssertFalse(service.isOnBreak)
        XCTAssertEqual(engine.currentPoints, 38.0, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .balanced)
    }

    func testActiveVideoPlaybackPreventsChargeModeWhenHandsFree() {
        let engine = WellnessPointEngine(initialPoints: 41.0)
        let telemetry = MockTelemetryProvider()
        let service = ActivityMonitorService(
            engine: engine,
            telemetry: telemetry,
            idleBreakThresholdSeconds: 60.0
        )

        // Watching video in Safari where tabURL is nil but macOS reports active video playback assertion
        telemetry.bundleID = "com.apple.Safari"
        telemetry.videoPlaying = true
        telemetry.idleSeconds = 120.0
        service.performSampleTick()

        XCTAssertFalse(service.isOnBreak)
        XCTAssertTrue(service.isWatchingMediaOrDistraction)
        XCTAssertEqual(engine.currentPoints, 39.5, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .dopamineSad)
    }

    func testChromiumSNSSSessionURLExtractionSupportsOtherBrowsers() {
        var fakeSNSS = Data([0x53, 0x4E, 0x53, 0x53, 0x01, 0x00, 0x00, 0x00])
        fakeSNSS.append("https://github.com/AkramKs/bitz-mac\0".data(using: .utf8)!)
        fakeSNSS.append("https://www.netflix.com/watch/80057281\0".data(using: .utf8)!)

        let extracted = BrowserTabTelemetryReader.extractLatestURLFromChromiumSNSS(fakeSNSS)
        XCTAssertEqual(extracted, "https://www.netflix.com/watch/80057281")

        let engine = WellnessPointEngine(initialPoints: 50.0)
        let telemetry = MockTelemetryProvider()
        let service = ActivityMonitorService(engine: engine, telemetry: telemetry)
        XCTAssertFalse(
            service.isProductiveBundleID(
                "com.google.Chrome",
                activeTabURL: extracted,
                activeTabTitle: nil
            )
        )
    }

    func testThermalOverheatingByTemperatureAndThermalStateAndRecovery() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 60.0, riveController: spy)
        let telemetry = MockTelemetryProvider()
        let service = ActivityMonitorService(engine: engine, telemetry: telemetry)

        // 1. Spike CPU temperature > 80.0C -> actionable cool-down message
        telemetry.currentTemperatureCelsius = 85.0
        service.performSampleTick()
        XCTAssertTrue(service.isOverheatingActive)
        XCTAssertEqual(engine.currentState, .overheating)
        XCTAssertEqual(engine.activeSpeechBubbleText, "🔥 85°C HOT — QUIT UNUSED APPS OR DOCKER TO COOL DOWN!")
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

    func testCustomAppRulesAndSleepWakeHandling() {
        let engine = WellnessPointEngine(initialPoints: 50.0)
        let telemetry = MockTelemetryProvider()
        let service = ActivityMonitorService(engine: engine, telemetry: telemetry)

        // 1. Test Custom Rule marking
        telemetry.bundleID = "com.custom.game"
        service.performSampleTick()
        XCTAssertFalse(service.lastAppIsProductive)

        service.markFrontmostApp(asProductive: true)
        XCTAssertEqual(service.frontmostAppCustomRule, true)
        XCTAssertTrue(service.lastAppIsProductive)

        service.markFrontmostApp(asProductive: false)
        XCTAssertEqual(service.frontmostAppCustomRule, false)
        XCTAssertFalse(service.lastAppIsProductive)

        service.resetFrontmostAppRule()
        XCTAssertNil(service.frontmostAppCustomRule)

        // 2. Test Safari active tab inspection
        XCTAssertTrue(
            service.isProductiveBundleID("com.apple.Safari", activeTabURL: "https://github.com/apple/swift")
        )
        XCTAssertFalse(
            service.isProductiveBundleID("com.apple.Safari", activeTabURL: "https://www.youtube.com/watch?v=123")
        )

        // 3. Test Sleep and Wake cycle crediting break
        engine.setPoints(20.0, continuousWorkMinutes: 40.0)
        telemetry.currentDate = Date()
        service.handleSystemSleepOrLock()

        // Fast forward 15 minutes
        telemetry.currentDate = telemetry.currentDate.addingTimeInterval(15.0 * 60.0)
        service.handleSystemWakeOrUnlock()

        // 20.0 + (15.0 * 5.0) = 95.0 pts, streak reset to 0
        XCTAssertGreaterThanOrEqual(engine.currentPoints, 90.0)
        XCTAssertEqual(engine.continuousWorkMinutes, 0.0)
    }
}
