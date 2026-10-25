import AppKit
import CoreGraphics
import Foundation

// MARK: - ActivityTelemetryProviding Seam

/// Protocol abstracting macOS foreground application, user input idle duration,
/// and system thermal state queries for deterministic, privacy-safe telemetry.
@MainActor
public protocol ActivityTelemetryProviding {
    /// Returns the bundle identifier of the currently active foreground application, if any.
    func frontmostBundleIdentifier() -> String?

    /// Returns the number of seconds elapsed since the last mouse or keyboard event.
    func secondsSinceLastInput() -> TimeInterval

    /// Returns the current macOS system thermal state.
    func thermalState() -> ProcessInfo.ThermalState

    /// Returns an optional CPU package/die temperature in Celsius if available.
    func cpuTemperatureCelsius() -> Double?

    /// Returns the current timestamp for deterministic break duration calculation.
    func now() -> Date
}

/// Production macOS telemetry provider backed by `NSWorkspace`, `CGEventSource`, and `ProcessInfo`.
/// Strictly complies with `C-003` (zero Accessibility or keylogging APIs).
@MainActor
public struct SystemActivityTelemetryProvider: ActivityTelemetryProviding {
    public init() {}

    public func frontmostBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    public func secondsSinceLastInput() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
    }

    public func thermalState() -> ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }

    public func cpuTemperatureCelsius() -> Double? {
        nil
    }

    public func now() -> Date {
        Date()
    }
}

// MARK: - ActivityMonitorService

/// Monitors active foreground application bundle identifiers, user input idle breaks,
/// and system thermal pressure to drive `WellnessPointEngine` updates.
@MainActor
public final class ActivityMonitorService {
    /// Default whitelist of productive developer/creative bundle identifiers.
    public static let defaultProductiveBundleIDs: Set<String> = [
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.todesktop.230313mzl4w4u92",
        "dev.warp.Warp-Stable",
        "com.jetbrains.intellij"
    ]

    public let engine: WellnessPointEngine
    public let telemetry: ActivityTelemetryProviding
    public let productiveBundleIDs: Set<String>
    public let idleBreakThresholdSeconds: TimeInterval
    public let overheatingTemperatureThresholdCelsius: Double

    public private(set) var isMonitoring: Bool = false
    public private(set) var isOnBreak: Bool = false
    public private(set) var breakStartedAt: Date? = nil
    public private(set) var isOverheatingActive: Bool = false

    private var pollingTimer: Timer?

    public init(
        engine: WellnessPointEngine,
        telemetry: ActivityTelemetryProviding = SystemActivityTelemetryProvider(),
        productiveBundleIDs: Set<String> = ActivityMonitorService.defaultProductiveBundleIDs,
        idleBreakThresholdSeconds: TimeInterval = 60.0,
        overheatingTemperatureThresholdCelsius: Double = 80.0
    ) {
        self.engine = engine
        self.telemetry = telemetry
        self.productiveBundleIDs = productiveBundleIDs
        self.idleBreakThresholdSeconds = idleBreakThresholdSeconds
        self.overheatingTemperatureThresholdCelsius = overheatingTemperatureThresholdCelsius
    }

    /// Returns `true` if the given bundle identifier belongs to the configured productive app set.
    public func isProductiveBundleID(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return productiveBundleIDs.contains(bundleID)
    }

    /// Starts periodic telemetry sampling on the main run loop with timer coalescing tolerance (`NFR-001`).
    public func startMonitoring(intervalSeconds: TimeInterval = 5.0) {
        stopMonitoring()
        isMonitoring = true

        let timer = Timer(timeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performSampleTick()
            }
        }
        timer.tolerance = intervalSeconds * 0.2
        RunLoop.main.add(timer, forMode: .common)
        pollingTimer = timer
    }

    /// Stops periodic telemetry sampling.
    public func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isMonitoring = false
    }

    /// Executes a single telemetry sample cycle:
    /// 1. Checks thermal state (`> 80°C` or `.critical` / `.serious` thermal state).
    /// 2. Checks idle time via `secondsSinceLastInput()` for offline break entry/restoration.
    /// 3. Evaluates foreground app bundle identifier when actively working.
    public func performSampleTick() {
        evaluateThermalSample()

        let idleSeconds = telemetry.secondsSinceLastInput()
        let currentTime = telemetry.now()

        if idleSeconds >= idleBreakThresholdSeconds {
            if !isOnBreak {
                isOnBreak = true
                breakStartedAt = currentTime.addingTimeInterval(-idleSeconds)
            }
            return
        }

        if isOnBreak {
            let startTime = breakStartedAt ?? currentTime
            let elapsedMinutes = max(0.0, currentTime.timeIntervalSince(startTime) / 60.0)
            isOnBreak = false
            breakStartedAt = nil
            engine.applyOfflineBreak(minutes: elapsedMinutes)
        }

        let frontmostBundleID = telemetry.frontmostBundleIdentifier()
        let isProductive = isProductiveBundleID(frontmostBundleID)
        engine.evaluateWorkTick(isProductiveApp: isProductive)
    }

    private func evaluateThermalSample() {
        let state = telemetry.thermalState()
        let tempCelsius = telemetry.cpuTemperatureCelsius() ?? 0.0
        let shouldOverheat = (state == .critical || state == .serious || tempCelsius > overheatingTemperatureThresholdCelsius)

        if shouldOverheat {
            isOverheatingActive = true
            engine.triggerThermalWarning(isOverheating: true)
        } else if isOverheatingActive {
            isOverheatingActive = false
            engine.triggerThermalWarning(isOverheating: false)
        }
    }
}
