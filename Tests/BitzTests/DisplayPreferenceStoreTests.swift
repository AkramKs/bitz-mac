import AppKit
import SwiftUI
import XCTest
@testable import BitzCore

@MainActor
final class DisplayPreferenceStoreTests: XCTestCase {

    func testDefaultDisplayPreferenceStoreInvariants() {
        let suiteName = "BitzDisplayDefaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DisplayPreferenceStore(userDefaults: defaults)
        XCTAssertEqual(store.targetMode, .primary)
        XCTAssertEqual(store.summaryTitle, "Primary")
        XCTAssertNil(store.targetDisplayID)
        XCTAssertNil(store.targetDisplayName)
        XCTAssertFalse(store.connectedScreens.isEmpty)

        // Verify connected screens inventory
        for screen in store.connectedScreens {
            XCTAssertFalse(screen.name.isEmpty)
            XCTAssertGreaterThan(screen.frame.width, 0)
            XCTAssertGreaterThan(screen.frame.height, 0)
        }
    }

    func testDisplayPreferenceStoreUserDefaultsPersistence() {
        let suiteName = "BitzDisplayPersistence.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store1 = DisplayPreferenceStore(userDefaults: defaults)
        var changedCount = 0
        store1.onDisplayPreferenceChanged = { changedCount += 1 }

        store1.selectMode(.followActive)
        XCTAssertEqual(store1.targetMode, .followActive)
        XCTAssertEqual(store1.summaryTitle, "Follow Active")
        XCTAssertEqual(changedCount, 1)

        store1.selectMode(.allDisplays)
        XCTAssertEqual(store1.targetMode, .allDisplays)
        XCTAssertEqual(store1.summaryTitle, "All Screens")
        XCTAssertEqual(changedCount, 2)

        store1.selectSpecificDisplay(id: 42, name: "Studio Display")
        XCTAssertEqual(store1.targetMode, .specific)
        XCTAssertEqual(store1.targetDisplayID, 42)
        XCTAssertEqual(store1.targetDisplayName, "Studio Display")
        XCTAssertEqual(store1.summaryTitle, "Studio Display")
        XCTAssertEqual(changedCount, 3)

        // Verify persistence in a brand new store using the same suite
        let store2 = DisplayPreferenceStore(userDefaults: defaults)
        XCTAssertEqual(store2.targetMode, .specific)
        XCTAssertEqual(store2.targetDisplayID, 42)
        XCTAssertEqual(store2.targetDisplayName, "Studio Display")
        XCTAssertEqual(store2.summaryTitle, "Studio Display")
    }

    func testSpecificDisplaySelectionAndFallbackResolution() {
        let suiteName = "BitzDisplayFallback.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DisplayPreferenceStore(userDefaults: defaults)
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let primaryScreen = screens.first!
        let primaryID = primaryScreen.displayID ?? 1
        let primaryName = primaryScreen.localizedName

        // 1. Exact match by ID
        store.selectSpecificDisplay(id: primaryID, name: primaryName)
        let resolvedById = store.resolveScreen(from: screens)
        XCTAssertEqual(resolvedById?.frame, primaryScreen.frame)

        // 2. Fallback matching by name when ID changed (e.g., reconnect)
        store.selectSpecificDisplay(id: 999999, name: primaryName)
        let resolvedByName = store.resolveScreen(from: screens)
        XCTAssertEqual(resolvedByName?.frame, primaryScreen.frame)

        // 3. Fallback to primary screen when both ID and name are not found (disconnected)
        store.selectSpecificDisplay(id: 999999, name: "Disconnected Monitor X")
        let resolvedFallback = store.resolveScreen(from: screens)
        XCTAssertEqual(resolvedFallback?.frame, primaryScreen.frame)
    }

    func testResolveScreenModes() {
        let suiteName = "BitzDisplayModes.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DisplayPreferenceStore(userDefaults: defaults)
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        // Primary
        store.selectMode(.primary)
        XCTAssertEqual(store.resolveScreen(from: screens)?.frame, screens.first?.frame)

        // All Displays
        store.selectMode(.allDisplays)
        XCTAssertEqual(store.resolveScreen(from: screens)?.frame, screens.first?.frame)

        // Follow Active
        store.selectMode(.followActive)
        let activeResolved = store.resolveScreen(from: screens)
        XCTAssertNotNil(activeResolved)
    }

    func testScreenContainingCursor() {
        let suiteName = "BitzCursorDetection.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DisplayPreferenceStore(userDefaults: defaults)
        let screens = NSScreen.screens
        guard let firstScreen = screens.first else { return }

        let centerPoint = NSPoint(x: firstScreen.frame.midX, y: firstScreen.frame.midY)
        let detectedScreen = store.screenContainingCursor(from: screens, cursorLocation: centerPoint)
        XCTAssertEqual(detectedScreen?.frame, firstScreen.frame)

        let offScreenPoint = NSPoint(x: -99999, y: -99999)
        let noneScreen = store.screenContainingCursor(from: screens, cursorLocation: offScreenPoint)
        XCTAssertNil(noneScreen)
    }

    func testDebouncedScreenParametersHandling() async {
        let panel = MascotOverlayPanel()
        panel.debounceInterval = 0.05 // 50ms for swift test

        // Rapidly trigger display change simulation
        for _ in 0..<5 {
            panel.handleScreenParametersChangedDebounced()
        }

        // Wait for debounce interval to pass
        try? await Task.sleep(nanoseconds: 80_000_000)

        // Panel frame is valid and within screen visible bounds
        XCTAssertGreaterThan(panel.frame.width, 0)
        XCTAssertGreaterThan(panel.frame.height, 0)
    }

    func testBitzAppDelegateMultiDisplaySyncAndAllScreens() {
        let suiteName = "BitzAppDelegateMultiDisplay.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let displayStore = DisplayPreferenceStore(userDefaults: defaults)
        let scaleStore = AvatarScaleStore(userDefaults: defaults)
        let delegate = BitzAppDelegate(
            scaleStore: scaleStore,
            displayStore: displayStore
        )

        delegate.setupOverlayPanel()
        XCTAssertNotNil(delegate.overlayPanel)
        XCTAssertEqual(delegate.overlayPanels.count, 1)

        // Switch to allDisplays mode
        displayStore.selectMode(.allDisplays)
        let screenCount = NSScreen.screens.count
        XCTAssertEqual(delegate.overlayPanels.count, screenCount)
        for panel in delegate.overlayPanels {
            XCTAssertTrue(panel.ignoresMouseEvents)
            XCTAssertFalse(panel.isOpaque)
        }

        // Switch back to primary
        displayStore.selectMode(.primary)
        XCTAssertEqual(delegate.overlayPanels.count, 1)
        XCTAssertNotNil(delegate.overlayPanel)
    }
}
