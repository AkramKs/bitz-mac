import AppKit
import Combine
import Foundation

/// Curated manual size presets for the Bitz desktop companion avatar relative to the `250×250` pt base canvas.
public enum AvatarSizePreset: Double, CaseIterable, Sendable {
    case small = 0.60
    case medium = 0.80
    case defaultSize = 1.00
    case large = 1.25
    case extraLarge = 1.50

    /// Percentage string representation (e.g., `"60%"`, `"100%"`, `"125%"`).
    public var percentageText: String {
        "\(Int((rawValue * 100.0).rounded()))%"
    }

    /// Rounded square point side length for this preset (e.g., `150`, `200`, `250`, `313`, `375`).
    public var pointDimension: Int {
        Int((MascotOverlayPanel.defaultPanelSize.width * rawValue).rounded())
    }

    /// Human-readable Menu Bar label displaying preset name, percentage, and point dimensions.
    public var menuTitle: String {
        let side = pointDimension
        switch self {
        case .small:
            return "Small — 60% (\(side)×\(side) pt)"
        case .medium:
            return "Medium — 80% (\(side)×\(side) pt)"
        case .defaultSize:
            return "Default — 100% (\(side)×\(side) pt)"
        case .large:
            return "Large — 125% (\(side)×\(side) pt)"
        case .extraLarge:
            return "XL — 150% (\(side)×\(side) pt)"
        }
    }
}

/// `@MainActor` observable store managing the user's manual avatar scale factor (`0.50...1.75`),
/// preset selection, `±10%` step adjustments, and `UserDefaults` persistence (`"avatarScaleFactor"`).
@MainActor
public final class AvatarScaleStore: ObservableObject {
    public static let defaultScaleFactor: Double = 1.00
    public static let minScaleFactor: Double = 0.50
    public static let maxScaleFactor: Double = 1.75
    public static let stepDelta: Double = 0.10
    public static let userDefaultsKey: String = "avatarScaleFactor"

    @Published public private(set) var scaleFactor: Double

    private let userDefaults: UserDefaults
    public var onScaleChanged: ((CGFloat) -> Void)?

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let rawStored = userDefaults.double(forKey: Self.userDefaultsKey)
        let initialScale = Self.sanitizeScaleFactor(rawStored)
        self.scaleFactor = initialScale
        if userDefaults.object(forKey: Self.userDefaultsKey) == nil {
            userDefaults.set(initialScale, forKey: Self.userDefaultsKey)
        }
    }

    /// Sanitizes an arbitrary scale input: non-finite or `<= 0` values fall back to `1.00`,
    /// and positive values are rounded to 2 decimal places and clamped to `0.50...1.75`.
    public static func sanitizeScaleFactor(_ rawValue: Double) -> Double {
        guard rawValue.isFinite, rawValue > 0.0 else {
            return defaultScaleFactor
        }
        let clamped = min(max(rawValue, minScaleFactor), maxScaleFactor)
        return (clamped * 100.0).rounded() / 100.0
    }

    /// Current scale expressed as an integer percentage (e.g., `100` for `1.00`).
    public var percentageInt: Int {
        Int((scaleFactor * 100.0).rounded())
    }

    /// Current scaled square point side length (e.g., `250` at `1.00`).
    public var pointDimensionInt: Int {
        Int((MascotOverlayPanel.defaultPanelSize.width * scaleFactor).rounded())
    }

    /// Formatted status summary for the Menu Bar header (e.g., `"100% (250×250 pt)"`).
    public var formattedSizeSummary: String {
        let side = pointDimensionInt
        return "\(percentageInt)% (\(side)×\(side) pt)"
    }

    /// Whether the scale can be decreased further before hitting `minScaleFactor` (`50%`).
    public var canStepDown: Bool {
        scaleFactor > Self.minScaleFactor + 0.001
    }

    /// Whether the scale can be increased further before hitting `maxScaleFactor` (`175%`).
    public var canStepUp: Bool {
        scaleFactor < Self.maxScaleFactor - 0.001
    }

    /// Sets and persists the avatar scale factor, clamping to `0.50...1.75` and notifying observers.
    public func setScale(_ newScale: Double) {
        let sanitized = Self.sanitizeScaleFactor(newScale)
        scaleFactor = sanitized
        userDefaults.set(sanitized, forKey: Self.userDefaultsKey)
        onScaleChanged?(CGFloat(sanitized))
    }

    /// Applies one of the curated `AvatarSizePreset` options.
    public func selectPreset(_ preset: AvatarSizePreset) {
        setScale(preset.rawValue)
    }

    /// Checks whether the given preset matches the active `scaleFactor`.
    public func isPresetSelected(_ preset: AvatarSizePreset) -> Bool {
        abs(scaleFactor - preset.rawValue) < 0.005
    }

    /// Increases the avatar scale by `+10%` (`+0.10`), clamped at `175%` (`1.75`).
    public func stepUp() {
        setScale(scaleFactor + Self.stepDelta)
    }

    /// Decreases the avatar scale by `-10%` (`-0.10`), clamped at `50%` (`0.50`).
    public func stepDown() {
        setScale(scaleFactor - Self.stepDelta)
    }

    /// Resets the avatar scale back to `100%` (`1.00`, `250×250` pt).
    public func resetToDefault() {
        setScale(Self.defaultScaleFactor)
    }
}

/// Borderless, transparent, floating, click-through `NSPanel` hosting Bitz in the bottom-right
/// corner of the active screen without stealing focus or intercepting mouse events (`FR-001`, `DIR-001`).
@MainActor
public final class MascotOverlayPanel: NSPanel {
    nonisolated public static let defaultPanelSize = NSSize(width: 250.0, height: 250.0)
    nonisolated public static let rightEdgePadding: CGFloat = 20.0
    nonisolated public static let bottomEdgePadding: CGFloat = 20.0

    public private(set) var currentScaleFactor: CGFloat = CGFloat(AvatarScaleStore.defaultScaleFactor)

    public init(
        contentRect: NSRect = NSRect(
            origin: .zero,
            size: MascotOverlayPanel.defaultPanelSize
        )
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.positionInBottomRight()
            }
        }
    }

    /// Computes the scaled square panel dimensions (`250 * scaleFactor` × `250 * scaleFactor`),
    /// optionally bounded to fit inside a constrained `visibleFrame` with `20 pt` margins.
    public static func calculatePanelSize(
        for scaleFactor: CGFloat = CGFloat(AvatarScaleStore.defaultScaleFactor),
        visibleFrame: NSRect? = nil
    ) -> NSSize {
        let sanitized = CGFloat(AvatarScaleStore.sanitizeScaleFactor(Double(scaleFactor)))
        var side = defaultPanelSize.width * sanitized
        if let visibleFrame {
            let maxAvailableWidth = max(defaultPanelSize.width * CGFloat(AvatarScaleStore.minScaleFactor), visibleFrame.width - (rightEdgePadding * 2.0))
            let maxAvailableHeight = max(defaultPanelSize.height * CGFloat(AvatarScaleStore.minScaleFactor), visibleFrame.height - (bottomEdgePadding * 2.0))
            side = min(side, min(maxAvailableWidth, maxAvailableHeight))
        }
        return NSSize(width: side, height: side)
    }

    /// Computes the bottom-right origin (`maxX - panelSize.width - 20`, `minY + 20`)
    /// within the given screen `visibleFrame`.
    public static func calculateOrigin(
        for visibleFrame: NSRect,
        panelSize: NSSize = defaultPanelSize
    ) -> NSPoint {
        NSPoint(
            x: visibleFrame.maxX - panelSize.width - rightEdgePadding,
            y: visibleFrame.minY + bottomEdgePadding
        )
    }

    /// Updates `currentScaleFactor`, resizes the hosted `contentView`, and re-anchors the panel
    /// in the bottom-right corner of `screen`.
    public func applyScaleFactor(_ scaleFactor: CGFloat, on screen: NSScreen? = NSScreen.main) {
        self.currentScaleFactor = CGFloat(AvatarScaleStore.sanitizeScaleFactor(Double(scaleFactor)))
        positionInBottomRight(of: screen)
    }

    /// Anchors the panel in the bottom-right corner of the specified `screen` (defaulting to `NSScreen.main`)
    /// using the active `currentScaleFactor`.
    public func positionInBottomRight(of screen: NSScreen? = NSScreen.main) {
        let targetFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let scaledSize = Self.calculatePanelSize(for: currentScaleFactor, visibleFrame: targetFrame)
        let origin = Self.calculateOrigin(for: targetFrame, panelSize: scaledSize)
        contentView?.frame = NSRect(origin: .zero, size: scaledSize)
        setFrame(NSRect(origin: origin, size: scaledSize), display: true)
    }

    public override var canBecomeKey: Bool {
        false
    }

    public override var canBecomeMain: Bool {
        false
    }
}
