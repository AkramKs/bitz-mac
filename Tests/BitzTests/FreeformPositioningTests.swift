import AppKit
@testable import BitzCore
import XCTest

@MainActor
final class FreeformPositioningTests: XCTestCase {

    private func createIsolatedDefaults() -> (UserDefaults, () -> Void) {
        let suiteName = "FreeformPositioningTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let cleanup = {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return (defaults, cleanup)
    }

    func testDefaultPositionModeIsCornerBottomRight() {
        let (defaults, cleanup) = createIsolatedDefaults()
        defer { cleanup() }

        let store = AvatarPositionStore(userDefaults: defaults)
        XCTAssertEqual(store.cornerAnchor, .bottomRight)
        XCTAssertEqual(store.positionMode, .corner(.bottomRight))
        XCTAssertNil(store.customOrigin)
        XCTAssertFalse(store.isFreeform)
        XCTAssertTrue(store.isCornerSelected(.bottomRight))
        XCTAssertFalse(store.isCornerSelected(.topLeft))
        XCTAssertEqual(store.formattedPositionSummary, "Bottom-Right (Default)")
    }

    func testSelectCornerUpdatesCornerAndPersists() {
        let (defaults, cleanup) = createIsolatedDefaults()
        defer { cleanup() }

        let store = AvatarPositionStore(userDefaults: defaults)
        var cornerCallbackInvoked = false
        var modeCallbackInvoked = false

        store.onCornerChanged = { corner in
            if corner == .topLeft {
                cornerCallbackInvoked = true
            }
        }
        store.onPositionModeChanged = { mode in
            if case .corner(let c) = mode, c == .topLeft {
                modeCallbackInvoked = true
            }
        }

        store.selectCorner(.topLeft)

        XCTAssertEqual(store.cornerAnchor, .topLeft)
        XCTAssertEqual(store.positionMode, .corner(.topLeft))
        XCTAssertNil(store.customOrigin)
        XCTAssertFalse(store.isFreeform)
        XCTAssertTrue(store.isCornerSelected(.topLeft))
        XCTAssertFalse(store.isCornerSelected(.bottomRight))
        XCTAssertTrue(cornerCallbackInvoked)
        XCTAssertTrue(modeCallbackInvoked)

        // Verify persistence in userDefaults
        XCTAssertEqual(defaults.string(forKey: AvatarPositionStore.userDefaultsKey), ScreenCornerAnchor.topLeft.rawValue)
        XCTAssertFalse(defaults.bool(forKey: AvatarPositionStore.isFreeformKey))
    }

    func testSetCustomPositionSwitchesToFreeformAndPersists() {
        let (defaults, cleanup) = createIsolatedDefaults()
        defer { cleanup() }

        let store = AvatarPositionStore(userDefaults: defaults)
        var positionCallbackInvoked = false
        var modeCallbackInvoked = false

        store.onCustomPositionChanged = { point in
            if point.x == 450.0 && point.y == 320.0 {
                positionCallbackInvoked = true
            }
        }
        store.onPositionModeChanged = { mode in
            if case .freeform(let x, let y) = mode, x == 450.0, y == 320.0 {
                modeCallbackInvoked = true
            }
        }

        store.setCustomPosition(NSPoint(x: 450.0, y: 320.0))

        XCTAssertTrue(store.isFreeform)
        XCTAssertEqual(store.customOrigin, NSPoint(x: 450.0, y: 320.0))
        XCTAssertEqual(store.positionMode, .freeform(x: 450.0, y: 320.0))
        XCTAssertFalse(store.isCornerSelected(.bottomRight))
        XCTAssertEqual(store.formattedPositionSummary, "Freeform (Custom)")
        XCTAssertTrue(positionCallbackInvoked)
        XCTAssertTrue(modeCallbackInvoked)

        // Check UserDefaults
        XCTAssertTrue(defaults.bool(forKey: AvatarPositionStore.isFreeformKey))
        XCTAssertEqual(defaults.double(forKey: AvatarPositionStore.customPositionXKey), 450.0)
        XCTAssertEqual(defaults.double(forKey: AvatarPositionStore.customPositionYKey), 320.0)
    }

    func testInitializationRestoresPersistedFreeformPosition() {
        let (defaults, cleanup) = createIsolatedDefaults()
        defer { cleanup() }

        defaults.set(true, forKey: AvatarPositionStore.isFreeformKey)
        defaults.set(780.0, forKey: AvatarPositionStore.customPositionXKey)
        defaults.set(510.0, forKey: AvatarPositionStore.customPositionYKey)

        let store = AvatarPositionStore(userDefaults: defaults)

        XCTAssertTrue(store.isFreeform)
        XCTAssertEqual(store.customOrigin, NSPoint(x: 780.0, y: 510.0))
        XCTAssertEqual(store.positionMode, .freeform(x: 780.0, y: 510.0))
        XCTAssertEqual(store.formattedPositionSummary, "Freeform (Custom)")
    }

    func testResetToDefaultCornerRevertsFreeform() {
        let (defaults, cleanup) = createIsolatedDefaults()
        defer { cleanup() }

        let store = AvatarPositionStore(userDefaults: defaults)
        store.setCustomPosition(NSPoint(x: 300, y: 400))
        XCTAssertTrue(store.isFreeform)

        store.resetToDefaultCorner()

        XCTAssertFalse(store.isFreeform)
        XCTAssertNil(store.customOrigin)
        XCTAssertEqual(store.cornerAnchor, .bottomRight)
        XCTAssertEqual(store.positionMode, .corner(.bottomRight))
        XCTAssertFalse(defaults.bool(forKey: AvatarPositionStore.isFreeformKey))
    }

    func testInteractivityToggleAndModifierHandling() {
        let (defaults, cleanup) = createIsolatedDefaults()
        defer { cleanup() }

        let store = AvatarPositionStore(userDefaults: defaults)
        XCTAssertFalse(store.isInteractivityEnabled)
        XCTAssertFalse(store.isPositionUnlocked)
        XCTAssertFalse(store.isModifierHeld)

        var toggledState: Bool?
        store.onInteractivityToggled = { enabled in
            toggledState = enabled
        }

        // Toggle unlock
        store.togglePositionLock()
        XCTAssertTrue(store.isPositionUnlocked)
        XCTAssertTrue(store.isInteractivityEnabled)
        XCTAssertEqual(toggledState, true)

        store.togglePositionLock()
        XCTAssertFalse(store.isPositionUnlocked)
        XCTAssertFalse(store.isInteractivityEnabled)
        XCTAssertEqual(toggledState, false)

        // Hold modifier key
        store.setModifierHeld(true)
        XCTAssertTrue(store.isModifierHeld)
        XCTAssertTrue(store.isInteractivityEnabled)
        XCTAssertEqual(toggledState, true)

        // Modifier released
        store.setModifierHeld(false)
        XCTAssertFalse(store.isModifierHeld)
        XCTAssertFalse(store.isInteractivityEnabled)
        XCTAssertEqual(toggledState, false)
    }

    func testLockAndUnlockPositionMethods() {
        let (defaults, cleanup) = createIsolatedDefaults()
        defer { cleanup() }

        let store = AvatarPositionStore(userDefaults: defaults)
        XCTAssertFalse(store.isPositionUnlocked)
        XCTAssertFalse(store.isInteractivityEnabled)

        var toggledState: Bool?
        store.onInteractivityToggled = { enabled in
            toggledState = enabled
        }

        // Explicit unlock
        store.unlockPosition()
        XCTAssertTrue(store.isPositionUnlocked)
        XCTAssertTrue(store.isInteractivityEnabled)
        XCTAssertEqual(toggledState, true)

        // Explicit lock
        store.lockPosition()
        XCTAssertFalse(store.isPositionUnlocked)
        XCTAssertFalse(store.isInteractivityEnabled)
        XCTAssertEqual(toggledState, false)

        // Lock when modifier was held
        store.setModifierHeld(true)
        XCTAssertTrue(store.isModifierHeld)
        XCTAssertTrue(store.isInteractivityEnabled)

        store.lockPosition()
        XCTAssertFalse(store.isModifierHeld)
        XCTAssertFalse(store.isInteractivityEnabled)
    }

    func testMascotOverlayPanelRightClickLocksPosition() {
        let panel = MascotOverlayPanel()
        var rightClickCalled = false
        panel.onRightMouseDown = {
            rightClickCalled = true
        }

        panel.rightMouseDown(with: NSEvent())
        XCTAssertTrue(rightClickCalled)
    }

    func testClampingKeepsPanelWithinScreenVisibleFrame() {
        let visibleFrame = NSRect(x: 0, y: 25, width: 1728, height: 1092) // Display with Dock/Menubar
        let panelSize = NSSize(width: 250, height: 250)

        // 1. Off-screen left & bottom
        let offscreenLeftBottom = NSPoint(x: -100, y: -50)
        let clamped1 = MascotOverlayPanel.clampOriginToVisibleFrame(offscreenLeftBottom, panelSize: panelSize, visibleFrame: visibleFrame)
        XCTAssertGreaterThanOrEqual(clamped1.x, visibleFrame.minX)
        XCTAssertGreaterThanOrEqual(clamped1.y, visibleFrame.minY)

        // 2. Off-screen right & top
        let offscreenRightTop = NSPoint(x: 2000, y: 1500)
        let clamped2 = MascotOverlayPanel.clampOriginToVisibleFrame(offscreenRightTop, panelSize: panelSize, visibleFrame: visibleFrame)
        XCTAssertLessThanOrEqual(clamped2.x, visibleFrame.maxX - panelSize.width)
        XCTAssertLessThanOrEqual(clamped2.y, visibleFrame.maxY - panelSize.height)

        // 3. In the center: unchanged if away from snap thresholds
        let center = NSPoint(x: 800, y: 500)
        let clampedCenter = MascotOverlayPanel.clampOriginToVisibleFrame(center, panelSize: panelSize, visibleFrame: visibleFrame)
        XCTAssertEqual(clampedCenter.x, 800)
        XCTAssertEqual(clampedCenter.y, 500)
    }

    func testMagneticEdgeSnapping() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1000, height: 1000)
        let panelSize = NSSize(width: 200, height: 200)
        let margin: CGFloat = 20.0
        let snapThreshold: CGFloat = 20.0

        // Test snapping near left margin (20.0) -> input x = 25.0 (within 5pt of margin)
        let nearLeftMargin = NSPoint(x: 25.0, y: 400.0)
        let clampedLeft = MascotOverlayPanel.clampOriginToVisibleFrame(
            nearLeftMargin,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            snapThreshold: snapThreshold,
            margin: margin
        )
        XCTAssertEqual(clampedLeft.x, 20.0)
        XCTAssertEqual(clampedLeft.y, 400.0)

        // Test snapping near right margin (1000 - 200 - 20 = 780.0) -> input x = 772.0
        let nearRightMargin = NSPoint(x: 772.0, y: 400.0)
        let clampedRight = MascotOverlayPanel.clampOriginToVisibleFrame(
            nearRightMargin,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            snapThreshold: snapThreshold,
            margin: margin
        )
        XCTAssertEqual(clampedRight.x, 780.0)
        XCTAssertEqual(clampedRight.y, 400.0)

        // Test snapping near bottom margin (20.0) -> input y = 14.0
        let nearBottomMargin = NSPoint(x: 400.0, y: 14.0)
        let clampedBottom = MascotOverlayPanel.clampOriginToVisibleFrame(
            nearBottomMargin,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            snapThreshold: snapThreshold,
            margin: margin
        )
        XCTAssertEqual(clampedBottom.x, 400.0)
        XCTAssertEqual(clampedBottom.y, 20.0)

        // Test snapping near top margin (1000 - 200 - 20 = 780.0) -> input y = 790.0
        let nearTopMargin = NSPoint(x: 400.0, y: 790.0)
        let clampedTop = MascotOverlayPanel.clampOriginToVisibleFrame(
            nearTopMargin,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            snapThreshold: snapThreshold,
            margin: margin
        )
        XCTAssertEqual(clampedTop.x, 400.0)
        XCTAssertEqual(clampedTop.y, 780.0)
    }

    func testMascotOverlayPanelApplyCustomOriginAndRevert() {
        let panel = MascotOverlayPanel()

        // Apply custom origin
        panel.applyCustomOrigin(NSPoint(x: 350, y: 450))
        XCTAssertEqual(panel.customOrigin, NSPoint(x: 350, y: 450))

        // Revert to corner
        panel.applyCornerAnchor(.topLeft)
        XCTAssertNil(panel.customOrigin)
        XCTAssertEqual(panel.currentCornerAnchor, .topLeft)
    }

    func testMascotVisibilityToggleAndPersistence() {
        let (defaults, cleanup) = createIsolatedDefaults()
        defer { cleanup() }

        let store = AvatarPositionStore(userDefaults: defaults)
        XCTAssertTrue(store.isMascotVisible)

        var callbackCount = 0
        store.onVisibilityChanged = { isVisible in
            callbackCount += 1
        }

        store.toggleMascotVisibility()
        XCTAssertFalse(store.isMascotVisible)
        XCTAssertEqual(callbackCount, 1)

        store.setMascotVisible(true)
        XCTAssertTrue(store.isMascotVisible)
        XCTAssertEqual(callbackCount, 2)

        // Verify restoration from defaults
        let restoredStore = AvatarPositionStore(userDefaults: defaults)
        XCTAssertTrue(restoredStore.isMascotVisible)
    }
}
