import AppKit
import Foundation

/// Borderless, transparent, floating, click-through `NSPanel` hosting Bitz in the bottom-right
/// corner of the active screen without stealing focus or intercepting mouse events (`FR-001`, `DIR-001`).
@MainActor
public final class MascotOverlayPanel: NSPanel {
    public static let defaultPanelSize = NSSize(width: 250.0, height: 250.0)
    public static let rightEdgePadding: CGFloat = 20.0
    public static let bottomEdgePadding: CGFloat = 20.0

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

    /// Computes the bottom-right origin (`maxX - 270`, `minY + 20` for a `250x250` panel)
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

    /// Anchors the panel in the bottom-right corner of the specified `screen` (defaulting to `NSScreen.main`).
    public func positionInBottomRight(of screen: NSScreen? = NSScreen.main) {
        let targetFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = Self.calculateOrigin(for: targetFrame, panelSize: Self.defaultPanelSize)
        setFrame(NSRect(origin: origin, size: Self.defaultPanelSize), display: true)
    }

    public override var canBecomeKey: Bool {
        false
    }

    public override var canBecomeMain: Bool {
        false
    }
}
