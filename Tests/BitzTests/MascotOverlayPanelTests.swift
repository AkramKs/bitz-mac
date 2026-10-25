import AppKit
import SwiftUI
import XCTest
@testable import BitzCore

@MainActor
final class MascotOverlayPanelTests: XCTestCase {

    func testOverlayPanelWindowInvariantsMatchContractByteForByte() {
        let panel = MascotOverlayPanel()

        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.styleMask.contains(.borderless))
        XCTAssertEqual(panel.backingType, .buffered)
        XCTAssertTrue(panel.isFloatingPanel)
        XCTAssertEqual(panel.level, .floating)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertEqual(panel.backgroundColor, .clear)
        XCTAssertFalse(panel.hasShadow)
        XCTAssertFalse(panel.isMovableByWindowBackground)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)

        let expectedBehavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
        XCTAssertTrue(panel.collectionBehavior.contains(expectedBehavior))
    }

    func testBottomRightOriginCalculationAndScreenPositioning() {
        let visibleFrame = NSRect(x: 0.0, y: 40.0, width: 1920.0, height: 1040.0)
        let origin = MascotOverlayPanel.calculateOrigin(for: visibleFrame)

        // maxX (1920) - width (250) - rightEdgePadding (20) = 1650
        // minY (40) + bottomEdgePadding (20) = 60
        XCTAssertEqual(origin.x, 1650.0, accuracy: 0.001)
        XCTAssertEqual(origin.y, 60.0, accuracy: 0.001)

        let panel = MascotOverlayPanel()
        panel.positionInBottomRight(of: nil)
        XCTAssertEqual(panel.frame.size.width, 250.0, accuracy: 0.001)
        XCTAssertEqual(panel.frame.size.height, 250.0, accuracy: 0.001)
    }

    func testMascotOverlayViewVisorColorMappingAndRendering() {
        let cyan = MascotOverlayView.visorRGB(for: .balanced)
        XCTAssertEqual(cyan.red, 0.0, accuracy: 0.001)
        XCTAssertEqual(cyan.green, 240.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(cyan.blue, 1.0, accuracy: 0.001)

        let magenta = MascotOverlayView.visorRGB(for: .superCharged)
        XCTAssertEqual(magenta.red, 1.0, accuracy: 0.001)
        XCTAssertEqual(magenta.green, 0.0, accuracy: 0.001)
        XCTAssertEqual(magenta.blue, 127.0 / 255.0, accuracy: 0.001)

        let amber = MascotOverlayView.visorRGB(for: .overworked)
        XCTAssertEqual(amber.red, 1.0, accuracy: 0.001)
        XCTAssertEqual(amber.green, 176.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(amber.blue, 0.0, accuracy: 0.001)

        let red = MascotOverlayView.visorRGB(for: .overheating)
        XCTAssertEqual(red.red, 1.0, accuracy: 0.001)
        XCTAssertEqual(red.green, 30.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(red.blue, 30.0 / 255.0, accuracy: 0.001)
    }

    func testBitzAppDelegateLifecycleWiresOverlayPanelAndActivityMonitor() {
        let telemetry = MockTelemetryProvider()
        let delegate = BitzAppDelegate(telemetryProvider: telemetry)

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        XCTAssertNotNil(delegate.overlayPanel)
        XCTAssertEqual(delegate.overlayPanel?.ignoresMouseEvents, true)
        XCTAssertEqual(delegate.overlayPanel?.isOpaque, false)
        XCTAssertTrue(delegate.activityMonitor.isMonitoring)

        delegate.engine.triggerThermalWarning(isOverheating: true)
        XCTAssertEqual(delegate.engine.activeSpeechBubbleText, "SYSTEM HOT! > <")

        delegate.engine.triggerPetInteraction()
        XCTAssertEqual(delegate.riveController.lastTriggeredInput, "triggerPet")

        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        XCTAssertFalse(delegate.activityMonitor.isMonitoring)
    }
}
