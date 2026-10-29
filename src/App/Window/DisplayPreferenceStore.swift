import AppKit
import Combine
import Foundation

/// Target display selection mode for mascot placement.
public enum DisplayTargetMode: String, CaseIterable, Sendable {
    case primary = "primary"
    case followActive = "followActive"
    case specific = "specific"
    case allDisplays = "allDisplays"

    public var menuTitle: String {
        switch self {
        case .primary: return "Primary Screen"
        case .followActive: return "Follow Active Screen"
        case .specific: return "Specific Screen"
        case .allDisplays: return "All Screens"
        }
    }
}

/// Representation of a connected physical or virtual display.
public struct ConnectedScreenInfo: Identifiable, Equatable, Sendable {
    public let id: CGDirectDisplayID
    public let name: String
    public let frame: NSRect
    public let visibleFrame: NSRect
    public let isPrimary: Bool
    public let backingScaleFactor: CGFloat

    public init(
        id: CGDirectDisplayID,
        name: String,
        frame: NSRect,
        visibleFrame: NSRect,
        isPrimary: Bool,
        backingScaleFactor: CGFloat
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.isPrimary = isPrimary
        self.backingScaleFactor = backingScaleFactor
    }
}

extension NSScreen {
    /// Extracts the unique `CGDirectDisplayID` for this `NSScreen`, if available.
    public var displayID: CGDirectDisplayID? {
        if let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            return screenNumber
        }
        if let num = (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value {
            return CGDirectDisplayID(num)
        }
        return nil
    }
}

/// `@MainActor` observable store managing user display placement preferences,
/// connected screens inventory, screen resolution & fallbacks, and `UserDefaults` persistence.
@MainActor
public final class DisplayPreferenceStore: ObservableObject {
    public static let targetModeUserDefaultsKey = "avatarDisplayTargetMode"
    public static let targetIDUserDefaultsKey = "avatarDisplayTargetID"
    public static let targetNameUserDefaultsKey = "avatarDisplayTargetName"

    @Published public private(set) var targetMode: DisplayTargetMode
    @Published public private(set) var targetDisplayID: CGDirectDisplayID?
    @Published public private(set) var targetDisplayName: String?
    @Published public private(set) var connectedScreens: [ConnectedScreenInfo] = []

    private let userDefaults: UserDefaults
    public var onDisplayPreferenceChanged: (() -> Void)?

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let rawMode = userDefaults.string(forKey: Self.targetModeUserDefaultsKey),
           let mode = DisplayTargetMode(rawValue: rawMode) {
            self.targetMode = mode
        } else {
            self.targetMode = .primary
            userDefaults.set(DisplayTargetMode.primary.rawValue, forKey: Self.targetModeUserDefaultsKey)
        }

        let storedID = userDefaults.object(forKey: Self.targetIDUserDefaultsKey) as? UInt32
        self.targetDisplayID = storedID.map { CGDirectDisplayID($0) }
        self.targetDisplayName = userDefaults.string(forKey: Self.targetNameUserDefaultsKey)

        refreshConnectedScreens()
    }

    /// Short label summarizing the active display choice for the Menu Bar header.
    public var summaryTitle: String {
        switch targetMode {
        case .primary:
            return "Primary"
        case .followActive:
            return "Follow Active"
        case .allDisplays:
            return "All Screens"
        case .specific:
            if let targetDisplayName, !targetDisplayName.isEmpty {
                return targetDisplayName
            } else if let targetDisplayID {
                return "Screen #\(targetDisplayID)"
            } else {
                return "Specific"
            }
        }
    }

    /// Selects a display target mode (`.primary`, `.followActive`, or `.allDisplays`).
    public func selectMode(_ mode: DisplayTargetMode) {
        targetMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.targetModeUserDefaultsKey)
        onDisplayPreferenceChanged?()
    }

    /// Selects a specific display target by `CGDirectDisplayID` and localized display name.
    public func selectSpecificDisplay(id: CGDirectDisplayID, name: String) {
        targetMode = .specific
        targetDisplayID = id
        targetDisplayName = name
        userDefaults.set(DisplayTargetMode.specific.rawValue, forKey: Self.targetModeUserDefaultsKey)
        userDefaults.set(UInt32(id), forKey: Self.targetIDUserDefaultsKey)
        userDefaults.set(name, forKey: Self.targetNameUserDefaultsKey)
        onDisplayPreferenceChanged?()
    }

    /// Refreshes the cached list of connected display information.
    public func refreshConnectedScreens(from screens: [NSScreen] = NSScreen.screens) {
        self.connectedScreens = screens.enumerated().map { index, screen in
            let id = screen.displayID ?? CGDirectDisplayID(index + 1)
            let name = screen.localizedName.isEmpty ? "Display \(index + 1)" : screen.localizedName
            let isPrimary = (index == 0)
            return ConnectedScreenInfo(
                id: id,
                name: name,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                isPrimary: isPrimary,
                backingScaleFactor: screen.backingScaleFactor
            )
        }
    }

    /// Resolves the target `NSScreen` based on user preference, with graceful fallback.
    public func resolveScreen(from screens: [NSScreen] = NSScreen.screens) -> NSScreen? {
        guard !screens.isEmpty else { return NSScreen.main }

        switch targetMode {
        case .primary:
            return screens.first ?? NSScreen.main

        case .followActive:
            return screenContainingCursor(from: screens) ?? NSScreen.main ?? screens.first

        case .specific:
            // 1. Try matching by CGDirectDisplayID
            if let targetID = targetDisplayID,
               let match = screens.first(where: { $0.displayID == targetID }) {
                return match
            }
            // 2. Fallback matching by display localizedName (e.g. if ID re-enumerated on reconnect)
            if let targetName = targetDisplayName,
               let match = screens.first(where: { $0.localizedName == targetName }) {
                return match
            }
            // 3. Fallback safely to primary screen if disconnected
            return screens.first ?? NSScreen.main

        case .allDisplays:
            return screens.first ?? NSScreen.main
        }
    }

    /// Finds the screen currently containing the mouse cursor location.
    public func screenContainingCursor(
        from screens: [NSScreen] = NSScreen.screens,
        cursorLocation: NSPoint = NSEvent.mouseLocation
    ) -> NSScreen? {
        screens.first(where: { NSPointInRect(cursorLocation, $0.frame) })
    }
}
