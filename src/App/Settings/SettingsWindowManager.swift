import AppKit
import SwiftUI

/// Manages a single-instance standard macOS Settings window for configuring
/// mascot appearance, wellness behaviors, telemetry, and AI coding agents.
///
/// Guaranteed Invariants:
/// - Single-instance lifecycle: bringing up settings when already open focuses the existing window.
/// - Mascot overlay panel invariant: `SettingsWindowManager` operates as a standard titled window and
///   never interferes with `MascotOverlayPanel.ignoresMouseEvents` or its non-activating behavior.
@MainActor
public final class SettingsWindowManager: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = SettingsWindowManager()

    private var windowController: NSWindowController?
    @Published public private(set) var isWindowOpen: Bool = false
    public var onWindowClosed: (() -> Void)?

    public override init() {
        super.init()
    }

    /// Returns the underlying NSWindow if instantiated.
    public var window: NSWindow? {
        windowController?.window
    }

    /// Presents the Settings window hosting the provided SwiftUI content view.
    /// If the window is already created, it is activated and brought to the front.
    public func showSettingsWindow<Content: View>(rootView: Content) {
        if let windowController = windowController, let existingWindow = windowController.window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            isWindowOpen = true
            return
        }

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 640, height: 520)
        window.center()
        window.title = "Bitz Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.delegate = self

        let controller = NSWindowController(window: window)
        self.windowController = controller

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isWindowOpen = true
    }

    /// Closes the Settings window if open.
    public func closeSettingsWindow() {
        windowController?.close()
        isWindowOpen = false
        onWindowClosed?()
    }

    // MARK: - NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        isWindowOpen = false
        onWindowClosed?()
    }
}
