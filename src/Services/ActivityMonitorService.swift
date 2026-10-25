import AppKit
import Combine
import CoreGraphics
import Darwin
import Foundation

// MARK: - Real Apple Silicon Hardware Sensor Reader

/// Reads live Apple Silicon die temperature sensors (`IOHIDEventSystemClient`) and
/// Mach kernel CPU load ticks (`host_statistics` with `HOST_CPU_LOAD_INFO`) without
/// requiring root privileges or private headers.
@MainActor
public final class AppleSiliconHardwareSensors {
    public static let shared = AppleSiliconHardwareSensors()

    private var previousCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?

    public init() {}

    /// Queries Apple Silicon `IOHIDEventSystemClient` thermal sensors (`PrimaryUsagePage: 0xFF00`, `PrimaryUsage: 5`)
    /// and returns the maximum active die/SOC temperature in degrees Celsius.
    public func readMaxDieTemperatureCelsius() -> Double? {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else {
            return nil
        }
        typealias CreateFn = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
        typealias SetMatchingFn = @convention(c) (AnyObject, CFDictionary) -> Void
        typealias CopyServicesFn = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
        typealias CopyEventFn = @convention(c) (AnyObject, Int64, Int32, Int64) -> Unmanaged<AnyObject>?
        typealias GetFloatFn = @convention(c) (AnyObject, Int32) -> Double

        guard let createSym = dlsym(handle, "IOHIDEventSystemClientCreate"),
              let matchSym = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
              let servicesSym = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
              let eventSym = dlsym(handle, "IOHIDServiceClientCopyEvent"),
              let floatSym = dlsym(handle, "IOHIDEventGetFloatValue") else {
            return nil
        }

        let create = unsafeBitCast(createSym, to: CreateFn.self)
        let setMatching = unsafeBitCast(matchSym, to: SetMatchingFn.self)
        let copyServices = unsafeBitCast(servicesSym, to: CopyServicesFn.self)
        let copyEvent = unsafeBitCast(eventSym, to: CopyEventFn.self)
        let getFloat = unsafeBitCast(floatSym, to: GetFloatFn.self)

        guard let client = create(kCFAllocatorDefault)?.takeRetainedValue() else {
            return nil
        }
        let matching: [String: Int] = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5]
        setMatching(client, matching as CFDictionary)

        guard let servicesRef = copyServices(client)?.takeRetainedValue() else {
            return nil
        }
        let count = CFArrayGetCount(servicesRef)
        var validTemperatures: [Double] = []
        validTemperatures.reserveCapacity(count)

        for index in 0..<count {
            guard let rawPtr = CFArrayGetValueAtIndex(servicesRef, index) else { continue }
            let service = Unmanaged<AnyObject>.fromOpaque(rawPtr).takeUnretainedValue()
            if let event = copyEvent(service, 15, 0, 0)?.takeRetainedValue() {
                let celsius = getFloat(event, 15 << 16)
                if celsius > 15.0 && celsius < 130.0 {
                    validTemperatures.append(celsius)
                }
            }
        }
        return validTemperatures.max()
    }

    /// Reads real-time system-wide CPU load percentage (`0.0 ... 100.0`) from the Mach kernel via `HOST_CPU_LOAD_INFO`.
    public func readSystemCPULoadPercentage() -> Double? {
        var size = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        var cpuLoad = host_cpu_load_info()
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(hostPort, HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        mach_port_deallocate(mach_task_self_, hostPort)
        guard result == KERN_SUCCESS else { return nil }

        let current = (
            user: UInt64(cpuLoad.cpu_ticks.0),
            system: UInt64(cpuLoad.cpu_ticks.1),
            idle: UInt64(cpuLoad.cpu_ticks.2),
            nice: UInt64(cpuLoad.cpu_ticks.3)
        )
        defer { previousCPUTicks = current }

        guard let previous = previousCPUTicks else {
            let total = current.user + current.system + current.idle + current.nice
            guard total > 0 else { return 0.0 }
            let busy = current.user + current.system + current.nice
            return (Double(busy) / Double(total)) * 100.0
        }

        let userDelta = current.user >= previous.user ? current.user - previous.user : 0
        let systemDelta = current.system >= previous.system ? current.system - previous.system : 0
        let idleDelta = current.idle >= previous.idle ? current.idle - previous.idle : 0
        let niceDelta = current.nice >= previous.nice ? current.nice - previous.nice : 0

        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
        guard totalDelta > 0 else { return 0.0 }
        let busyDelta = userDelta + systemDelta + niceDelta
        return (Double(busyDelta) / Double(totalDelta)) * 100.0
    }
}

// MARK: - ActivityTelemetryProviding Seam

/// Protocol abstracting macOS foreground application, user input idle duration,
/// and system thermal state queries for deterministic, privacy-safe telemetry.
@MainActor
public protocol ActivityTelemetryProviding {
    /// Returns the bundle identifier of the currently active foreground application, if any.
    func frontmostBundleIdentifier() -> String?

    /// Returns the localized name of the currently active foreground application, if any.
    func frontmostApplicationName() -> String?

    /// Returns the number of seconds elapsed since the last mouse or keyboard event.
    func secondsSinceLastInput() -> TimeInterval

    /// Returns the current macOS system thermal state.
    func thermalState() -> ProcessInfo.ThermalState

    /// Returns an optional CPU package/die temperature in Celsius if available.
    func cpuTemperatureCelsius() -> Double?

    /// Returns an optional system-wide CPU load percentage (`0.0 ... 100.0`) if available.
    func cpuLoadPercentage() -> Double?

    /// Returns the current timestamp for deterministic break duration calculation.
    func now() -> Date
}

extension ActivityTelemetryProviding {
    public func frontmostApplicationName() -> String? {
        frontmostBundleIdentifier()
    }

    public func cpuLoadPercentage() -> Double? {
        nil
    }
}

/// Production macOS telemetry provider backed by `NSWorkspace`, `CGEventSource`, `ProcessInfo`,
/// and `AppleSiliconHardwareSensors` (`IOHIDEventSystemClient` + Mach `HOST_CPU_LOAD_INFO`).
/// Strictly complies with `C-003` (zero Accessibility or keylogging APIs).
@MainActor
public struct SystemActivityTelemetryProvider: ActivityTelemetryProviding {
    public init() {}

    public func frontmostBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    public func frontmostApplicationName() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }

    private static let trackedInputEventTypes: [CGEventType] = [
        .mouseMoved,
        .leftMouseDown,
        .leftMouseUp,
        .rightMouseDown,
        .scrollWheel,
        .keyDown,
        .flagsChanged
    ]

    public func secondsSinceLastInput() -> TimeInterval {
        Self.trackedInputEventTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0.0
    }

    public func thermalState() -> ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }

    public func cpuTemperatureCelsius() -> Double? {
        AppleSiliconHardwareSensors.shared.readMaxDieTemperatureCelsius()
    }

    public func cpuLoadPercentage() -> Double? {
        AppleSiliconHardwareSensors.shared.readSystemCPULoadPercentage()
    }

    public func now() -> Date {
        Date()
    }
}

// MARK: - ActivityMonitorService

/// Monitors active foreground application bundle identifiers, user input idle breaks,
/// and live hardware thermal/CPU sensors to drive `WellnessPointEngine` updates.
@MainActor
public final class ActivityMonitorService: ObservableObject {
    /// Default whitelist of productive developer/creative bundle identifiers.
    public static let defaultProductiveBundleIDs: Set<String> = [
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.todesktop.230313mzl4w4u92",
        "dev.warp.Warp-Stable",
        "com.jetbrains.intellij",
        "com.google.antigravity",
        "com.google.antigravity-ide",
        "dev.zed.Zed",
        "com.sublimetext.4"
    ]

    /// Substring keywords that also identify developer/creative tools by bundle ID.
    private static let productiveBundleKeywords: [String] = [
        "xcode", "vscode", "terminal", "iterm", "warp", "jetbrains", "antigravity", "cursor", "zed"
    ]

    public let engine: WellnessPointEngine
    public let telemetry: ActivityTelemetryProviding
    public let productiveBundleIDs: Set<String>
    public let idleBreakThresholdSeconds: TimeInterval
    public let overheatingTemperatureThresholdCelsius: Double

    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var isOnBreak: Bool = false
    @Published public private(set) var breakStartedAt: Date? = nil
    @Published public private(set) var isOverheatingActive: Bool = false

    @Published public private(set) var lastTemperatureCelsius: Double? = nil
    @Published public private(set) var lastCPULoadPercentage: Double? = nil
    @Published public private(set) var lastThermalState: ProcessInfo.ThermalState = .nominal
    @Published public private(set) var lastFrontmostBundleID: String? = nil
    @Published public private(set) var lastFrontmostAppName: String? = nil
    @Published public private(set) var lastIdleSeconds: TimeInterval = 0.0
    @Published public private(set) var lastAppIsProductive: Bool = false

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

    /// Returns `true` if the given bundle identifier belongs to the configured productive app set
    /// or matches known developer IDE/terminal bundle keywords.
    public func isProductiveBundleID(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        if productiveBundleIDs.contains(bundleID) {
            return true
        }
        let lower = bundleID.lowercased()
        return Self.productiveBundleKeywords.contains { lower.contains($0) }
    }

    /// Starts periodic telemetry sampling on the main run loop with timer coalescing tolerance (`NFR-001`).
    public func startMonitoring(intervalSeconds: TimeInterval = 5.0) {
        stopMonitoring()
        isMonitoring = true
        performSampleTick()

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
    /// 1. Samples real CPU die temperature (`°C`), CPU load (`%`), and `ProcessInfo.ThermalState`.
    /// 2. Checks idle time via `secondsSinceLastInput()` for offline break entry/restoration.
    /// 3. Evaluates foreground app bundle identifier when actively working.
    public func performSampleTick() {
        evaluateThermalSample()

        let idleSeconds = telemetry.secondsSinceLastInput()
        lastIdleSeconds = idleSeconds
        let currentTime = telemetry.now()

        let frontmostBundleID = telemetry.frontmostBundleIdentifier()
        lastFrontmostBundleID = frontmostBundleID
        lastFrontmostAppName = telemetry.frontmostApplicationName() ?? frontmostBundleID
        let isProductive = isProductiveBundleID(frontmostBundleID)
        lastAppIsProductive = isProductive

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

        engine.evaluateWorkTick(isProductiveApp: isProductive)
    }

    private func evaluateThermalSample() {
        let state = telemetry.thermalState()
        let tempCelsius = telemetry.cpuTemperatureCelsius()
        let cpuLoad = telemetry.cpuLoadPercentage()

        lastThermalState = state
        lastTemperatureCelsius = tempCelsius
        lastCPULoadPercentage = cpuLoad
        engine.latestTemperatureCelsius = tempCelsius
        engine.latestCPULoadPercentage = cpuLoad

        let effectiveTemp = tempCelsius ?? 0.0
        let shouldOverheat = (state == .critical || state == .serious || effectiveTemp > overheatingTemperatureThresholdCelsius)

        if shouldOverheat {
            isOverheatingActive = true
            engine.triggerThermalWarning(isOverheating: true)
        } else if isOverheatingActive {
            isOverheatingActive = false
            engine.triggerThermalWarning(isOverheating: false)
        }
    }
}
