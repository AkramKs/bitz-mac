import XCTest
import SwiftUI
@testable import BitzCore

@MainActor
final class SettingsWindowManagerTests: XCTestCase {
    func testSettingsWindowManagerInitialState() {
        let manager = SettingsWindowManager()
        XCTAssertFalse(manager.isWindowOpen)
        XCTAssertNil(manager.window)
    }

    func testShowSettingsWindowCreatesAndConfiguresWindow() {
        let manager = SettingsWindowManager()
        let sampleView = Text("Hello Settings")

        manager.showSettingsWindow(rootView: sampleView)

        XCTAssertTrue(manager.isWindowOpen)
        guard let window = manager.window else {
            XCTFail("Expected window to be instantiated")
            return
        }

        XCTAssertEqual(window.title, "Bitz Settings")
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertTrue(window.styleMask.contains(.miniaturizable))
        XCTAssertFalse(window.isReleasedWhenClosed)

        manager.closeSettingsWindow()
        XCTAssertFalse(manager.isWindowOpen)
    }

    func testShowSettingsWindowReusesExistingWindowInstance() {
        let manager = SettingsWindowManager()
        let sampleView1 = Text("Tab 1")
        let sampleView2 = Text("Tab 2")

        manager.showSettingsWindow(rootView: sampleView1)
        let firstWindow = manager.window

        manager.showSettingsWindow(rootView: sampleView2)
        let secondWindow = manager.window

        XCTAssertTrue(manager.isWindowOpen)
        XCTAssertEqual(firstWindow, secondWindow, "Window manager must reuse existing window instance")

        manager.closeSettingsWindow()
        XCTAssertFalse(manager.isWindowOpen)
    }

    func testSettingsWindowCloseInvokesOnWindowClosed() {
        let manager = SettingsWindowManager()
        var closeCallbackInvoked = false
        manager.onWindowClosed = {
            closeCallbackInvoked = true
        }

        manager.showSettingsWindow(rootView: Text("Settings Content"))
        XCTAssertTrue(manager.isWindowOpen)
        XCTAssertFalse(closeCallbackInvoked)

        manager.closeSettingsWindow()
        XCTAssertFalse(manager.isWindowOpen)
        XCTAssertTrue(closeCallbackInvoked)
    }
}
