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

// MARK: - Browser Active Tab Reader (Zero-Permission Firefox mozLz40 Session Reader)

/// Reads the active browser tab URL and title from Firefox's live `recovery.jsonlz4` session store
/// without requiring Accessibility or AppleEvents permissions.
@MainActor
public enum BrowserTabTelemetryReader {
    /// Decompresses a Mozilla `mozLz40\0` LZ4 block into raw JSON `Data`.
    public static func decompressMozLZ4(_ data: Data) -> Data? {
        guard data.count > 12 else { return nil }
        let magic = String(data: data.subdata(in: 0..<7), encoding: .ascii)
        guard magic == "mozLz40" else { return nil }

        let expectedSize = data.subdata(in: 8..<12).withUnsafeBytes {
            $0.load(as: UInt32.self).littleEndian
        }
        guard expectedSize > 0 && expectedSize < 50_000_000 else { return nil }

        var out = Data()
        out.reserveCapacity(Int(expectedSize))

        let src = [UInt8](data.subdata(in: 12..<data.count))
        var ip = 0
        let end = src.count

        while ip < end {
            let token = Int(src[ip])
            ip += 1

            var literalLength = token >> 4
            if literalLength == 15 {
                while ip < end {
                    let s = Int(src[ip])
                    ip += 1
                    literalLength += s
                    if s != 255 { break }
                }
            }
            guard ip + literalLength <= end else { break }
            out.append(contentsOf: src[ip..<(ip + literalLength)])
            ip += literalLength

            if ip >= end { break }
            guard ip + 2 <= end else { break }
            let offset = Int(src[ip]) | (Int(src[ip + 1]) << 8)
            ip += 2
            guard offset > 0 && offset <= out.count else { break }

            var matchLength = (token & 0x0F) + 4
            if (token & 0x0F) == 15 {
                while ip < end {
                    let s = Int(src[ip])
                    ip += 1
                    matchLength += s
                    if s != 255 { break }
                }
            }

            let matchStart = out.count - offset
            for i in 0..<matchLength {
                out.append(out[matchStart + i])
            }
        }
        return out
    }

    /// Reads the currently selected tab's `(url, title)` from the user's active Firefox profile.
    public static func readActiveFirefoxTab() -> (url: String?, title: String?) {
        let fm = FileManager.default
        let profilesDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Firefox/Profiles")
        guard let profiles = try? fm.contentsOfDirectory(at: profilesDir, includingPropertiesForKeys: nil) else {
            return (nil, nil)
        }

        var latestSessionURL: URL?
        var latestModDate: Date = .distantPast

        for profile in profiles {
            let candidate = profile.appendingPathComponent("sessionstore-backups/recovery.jsonlz4")
            if let attrs = try? fm.attributesOfItem(atPath: candidate.path),
               let modDate = attrs[.modificationDate] as? Date,
               modDate > latestModDate {
                latestModDate = modDate
                latestSessionURL = candidate
            }
        }

        guard let sessionFile = latestSessionURL,
              let raw = try? Data(contentsOf: sessionFile),
              let decompressed = decompressMozLZ4(raw),
              let json = try? JSONSerialization.jsonObject(with: decompressed) as? [String: Any],
              let windows = json["windows"] as? [[String: Any]],
              !windows.isEmpty else {
            return (nil, nil)
        }

        let selectedWinIdx = max(0, min(windows.count - 1, ((json["selectedWindow"] as? Int) ?? 1) - 1))
        let win = windows[selectedWinIdx]
        guard let tabs = win["tabs"] as? [[String: Any]], !tabs.isEmpty else {
            return (nil, nil)
        }

        let selectedTabIdx = max(0, min(tabs.count - 1, ((win["selected"] as? Int) ?? 1) - 1))
        let tab = tabs[selectedTabIdx]
        guard let entries = tab["entries"] as? [[String: Any]], !entries.isEmpty else {
            return (nil, nil)
        }

        let entryIdx = max(0, min(entries.count - 1, ((tab["index"] as? Int) ?? entries.count) - 1))
        let entry = entries[entryIdx]
        return (entry["url"] as? String, entry["title"] as? String)
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

    /// Returns the URL of the currently active browser tab, if the frontmost app is a supported browser.
    func activeBrowserTabURL() -> String?

    /// Returns the title of the currently active browser tab, if the frontmost app is a supported browser.
    func activeBrowserTabTitle() -> String?

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

    public func activeBrowserTabURL() -> String? {
        nil
    }

    public func activeBrowserTabTitle() -> String? {
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

    public func activeBrowserTabURL() -> String? {
        guard let bundleID = frontmostBundleIdentifier()?.lowercased(),
              bundleID.contains("firefox") || bundleID.contains("zen") || bundleID.contains("waterfox") else {
            return nil
        }
        return BrowserTabTelemetryReader.readActiveFirefoxTab().url
    }

    public func activeBrowserTabTitle() -> String? {
        guard let bundleID = frontmostBundleIdentifier()?.lowercased(),
              bundleID.contains("firefox") || bundleID.contains("zen") || bundleID.contains("waterfox") else {
            return nil
        }
        return BrowserTabTelemetryReader.readActiveFirefoxTab().title
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
    /// Default whitelist of productive developer, creative, and office bundle identifiers.
    public static let defaultProductiveBundleIDs: Set<String> = [
        // Code Editors, IDEs & AI Coding Assistants
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.google.antigravity",
        "com.google.antigravity-ide",
        "com.google.GeminiMacOS",
        "com.openai.chat",
        "com.anthropic.claudefordesktop",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.exafunction.windsurf",
        "dev.zed.Zed",
        "com.sublimetext.4",
        "com.sublimetext.3",
        "com.panic.Nova",
        "abnerworks.Typora",

        // Terminals
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "co.zeit.hyper",

        // JetBrains & Android Studio
        "com.jetbrains.intellij",
        "com.jetbrains.intellij.ce",
        "com.jetbrains.pycharm",
        "com.jetbrains.pycharm.ce",
        "com.jetbrains.WebStorm",
        "com.jetbrains.goland",
        "com.jetbrains.CLion",
        "com.jetbrains.rider",
        "com.jetbrains.PhpStorm",
        "com.jetbrains.rubymine",
        "com.jetbrains.datagrip",
        "com.google.android.studio",

        // DevOps, Git, Databases & API Clients
        "com.docker.docker",
        "com.postmanlabs.mac",
        "com.insomnia.app",
        "com.tinyapp.TablePlus",
        "com.sequel-ace.sequel-ace",
        "com.mongodb.compass",
        "com.github.GitHubClient",
        "com.sublimemerge",
        "com.torusknot.SourceTreeNotMAS",
        "com.axosoft.gitkraken",

        // Microsoft Office & Teams Suite
        "com.microsoft.Word",
        "com.microsoft.Excel",
        "com.microsoft.Powerpoint",
        "com.microsoft.Outlook",
        "com.microsoft.onenote.mac",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.microsoft.to-do-mac",
        "com.microsoft.rdc.macos",

        // Apple iWork & Native Productivity Apps
        "com.apple.iWork.Pages",
        "com.apple.iWork.Numbers",
        "com.apple.iWork.Keynote",
        "com.apple.Notes",
        "com.apple.iCal",
        "com.apple.reminders",
        "com.apple.mail",
        "com.apple.TextEdit",
        "com.apple.Preview",
        "com.apple.freeform",
        "org.libreoffice.script",

        // Collaboration, Notes, Design & Project Management
        "com.tinyspeck.slackmacgap",
        "us.zoom.xos",
        "notion.id",
        "md.obsidian",
        "com.linear",
        "com.figma.Desktop",
        "com.bohemiancoding.sketch3",
        "com.canva.CanvaDesktop",
        "com.miro.miro",
        "com.atlassian.trello",
        "com.todoist.mac.Todoist",
        "com.culturedcode.ThingsMac",
        "com.flexibits.fantastical2.mac",
        "com.1password.1password"
    ]

    /// Substring keywords that also identify developer, creative, and office productivity tools by bundle ID.
    private static let productiveBundleKeywords: [String] = [
        "xcode", "vscode", "terminal", "iterm", "warp", "ghostty", "alacritty", "kitty",
        "jetbrains", "intellij", "pycharm", "webstorm", "goland", "clion", "phpstorm", "rubymine", "datagrip", "android.studio",
        "antigravity", "cursor", "windsurf", "zed", "sublimetext", "sublimemerge",
        "docker", "postman", "insomnia", "tableplus", "sequel", "gitkraken", "sourcetree", "githubclient",
        "gemini", "claude", "openai",
        "microsoft.word", "microsoft.excel", "microsoft.powerpoint", "microsoft.outlook", "microsoft.onenote", "microsoft.teams", "microsoft.to-do",
        "iwork.pages", "iwork.numbers", "iwork.keynote", "libreoffice",
        "apple.notes", "apple.ical", "apple.reminders", "apple.mail", "apple.textedit", "apple.preview", "apple.freeform",
        "slack", "zoom.xos", "notion", "obsidian", "linear", "figma", "sketch", "canva", "miro", "trello", "todoist", "thingsmac"
    ]

    /// Browser bundle ID keywords where work/research tabs (like GitHub, docs, Stack Overflow) are productive,
    /// while streaming & social media tabs (YouTube, Netflix, Instagram, Facebook, TikTok, etc.) drain PTS.
    private static let browserBundleKeywords: [String] = [
        "firefox", "chrome", "brave", "edgemac", "thebrowser.browser", "opera", "zen-browser", "waterfox"
    ]

    /// Streaming, video, and social media domains/keywords that trigger Dopamine Drain (`-1.5 PTS`).
    public static let dopamineStreamingAndSocialKeywords: [String] = [
        // Video & Streaming Providers
        "youtube.com", "youtu.be", "netflix.com", "twitch.tv", "disneyplus.com",
        "primevideo.com", "hbomax.com", "max.com", "hulu.com", "tv.apple.com",
        "crunchyroll.com", "dailymotion.com", "vimeo.com", "kick.com", "plex.tv",
        "peacocktv.com", "paramountplus.com", "viaplay.", "videoland.",
        // Social Media & Doomscrolling
        "facebook.com", "fb.com", "instagram.com", "tiktok.com", "twitter.com",
        "x.com/", "reddit.com", "snapchat.com", "pinterest.com", "9gag.com",
        "imgur.com", "threads.net", "bsky.app", "tumblr.com", "buzzfeed.com",
        // Personal Chat & Gaming Sites
        "web.whatsapp.com", "discord.com", "web.telegram.org", "messenger.com",
        "steampowered.com", "roblox.com", "epicgames.com"
    ]

    public let engine: WellnessPointEngine
    public let telemetry: ActivityTelemetryProviding
    public let productiveBundleIDs: Set<String>
    public let idleBreakThresholdSeconds: TimeInterval
    public let overheatingTemperatureThresholdCelsius: Double
    public let overheatingCPULoadThresholdPercent: Double

    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var isOnBreak: Bool = false
    @Published public private(set) var breakStartedAt: Date? = nil
    @Published public private(set) var isOverheatingActive: Bool = false
    @Published public var isManualOverrideActive: Bool = false

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
        overheatingTemperatureThresholdCelsius: Double = 80.0,
        overheatingCPULoadThresholdPercent: Double = 85.0
    ) {
        self.engine = engine
        self.telemetry = telemetry
        self.productiveBundleIDs = productiveBundleIDs
        self.idleBreakThresholdSeconds = idleBreakThresholdSeconds
        self.overheatingTemperatureThresholdCelsius = overheatingTemperatureThresholdCelsius
        self.overheatingCPULoadThresholdPercent = overheatingCPULoadThresholdPercent
    }

    /// Returns `true` if the given browser tab URL or title belongs to a streaming or social media platform
    /// (YouTube, Netflix, Disney+, Twitch, Facebook, Instagram, TikTok, X/Twitter, Reddit, etc.).
    public func isDopamineStreamingOrSocialTab(url: String?, title: String? = nil) -> Bool {
        if let url = url?.lowercased() {
            if Self.dopamineStreamingAndSocialKeywords.contains(where: { url.contains($0) }) {
                return true
            }
        }
        if let title = title?.lowercased() {
            let titleKeywords = ["youtube", "netflix", "twitch", "disney+", "prime video", "instagram", "facebook", "tiktok", "reddit"]
            if titleKeywords.contains(where: { title.contains($0) }) {
                return true
            }
        }
        return false
    }

    /// Returns `true` if the given bundle identifier (and optional active browser tab URL/title)
    /// represents productive work or research rather than streaming/social media distraction.
    public func isProductiveBundleID(_ bundleID: String?, activeTabURL: String? = nil, activeTabTitle: String? = nil) -> Bool {
        guard let bundleID else { return false }
        if isDopamineStreamingOrSocialTab(url: activeTabURL, title: activeTabTitle) {
            return false
        }
        if let url = activeTabURL, !url.isEmpty {
            return true
        }
        if productiveBundleIDs.contains(bundleID) {
            return true
        }
        let lower = bundleID.lowercased()
        if Self.productiveBundleKeywords.contains(where: { lower.contains($0) }) {
            return true
        }
        if Self.browserBundleKeywords.contains(where: { lower.contains($0) }) {
            return true
        }
        return false
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

    /// Clears any manual state override and immediately re-evaluates live hardware and activity sensors.
    public func clearManualOverride() {
        isManualOverrideActive = false
        isOverheatingActive = false
        engine.triggerThermalWarning(isOverheating: false)
        engine.setChargingState(false)
        performSampleTick()
    }

    /// Executes a single telemetry sample cycle:
    /// 1. Samples real CPU die temperature (`°C`), CPU load (`%`), and `ProcessInfo.ThermalState`.
    /// 2. Checks idle time via `secondsSinceLastInput()` for offline break entry/restoration.
    /// 3. Evaluates foreground app bundle identifier when actively working.
    public func performSampleTick() {
        let idleSeconds = telemetry.secondsSinceLastInput()
        lastIdleSeconds = idleSeconds
        let currentTime = telemetry.now()

        let frontmostBundleID = telemetry.frontmostBundleIdentifier()
        let activeTabURL = telemetry.activeBrowserTabURL()
        let activeTabTitle = telemetry.activeBrowserTabTitle()
        lastFrontmostBundleID = frontmostBundleID

        let baseAppName = telemetry.frontmostApplicationName() ?? frontmostBundleID ?? "Unknown"
        if let urlStr = activeTabURL, let host = URL(string: urlStr)?.host {
            let cleanHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            lastFrontmostAppName = "\(baseAppName) [\(cleanHost)]"
        } else {
            lastFrontmostAppName = baseAppName
        }

        let isProductive = isProductiveBundleID(
            frontmostBundleID,
            activeTabURL: activeTabURL,
            activeTabTitle: activeTabTitle
        )
        lastAppIsProductive = isProductive

        if isManualOverrideActive {
            let state = telemetry.thermalState()
            let tempCelsius = telemetry.cpuTemperatureCelsius()
            let cpuLoad = telemetry.cpuLoadPercentage()
            lastThermalState = state
            lastTemperatureCelsius = tempCelsius
            lastCPULoadPercentage = cpuLoad
            engine.latestTemperatureCelsius = tempCelsius
            engine.latestCPULoadPercentage = cpuLoad
            return
        }

        evaluateThermalSample()

        if idleSeconds >= idleBreakThresholdSeconds {
            if !isOnBreak {
                isOnBreak = true
                breakStartedAt = currentTime.addingTimeInterval(-idleSeconds)
            }
            engine.setChargingState(true)
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
        let effectiveLoad = cpuLoad ?? 0.0
        let isHotTemp = effectiveTemp > overheatingTemperatureThresholdCelsius
        let isHighCPU = effectiveLoad > overheatingCPULoadThresholdPercent
        let shouldOverheat = (state == .critical || state == .serious || isHotTemp || isHighCPU)

        if shouldOverheat {
            isOverheatingActive = true
            let actionMessage: String
            if isHotTemp && isHighCPU {
                actionMessage = String(
                    format: "🔥 %.0f°C (%.0f%% CPU) — CLOSE HEAVY TABS OR BUILDS TO COOL DOWN!",
                    effectiveTemp,
                    effectiveLoad
                )
            } else if isHotTemp {
                actionMessage = String(
                    format: "🔥 %.0f°C HOT — QUIT UNUSED APPS OR DOCKER TO COOL DOWN!",
                    effectiveTemp
                )
            } else if isHighCPU {
                actionMessage = String(
                    format: "🔥 %.0f%% CPU LOAD — QUIT HEAVY BACKGROUND APPS TO COOL DOWN!",
                    effectiveLoad
                )
            } else {
                actionMessage = WellnessPointEngine.thermalWarningText
            }
            engine.triggerThermalWarning(isOverheating: true, actionMessage: actionMessage)
        } else if isOverheatingActive {
            isOverheatingActive = false
            engine.triggerThermalWarning(isOverheating: false)
        }
    }
}
