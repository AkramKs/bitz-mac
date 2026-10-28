import XCTest
@testable import BitzCore

final class MockAgentAdapter: AgentAdapter, @unchecked Sendable {
    let id: String
    private var handler: (@Sendable (AgentEvent) -> Void)?

    init(id: String = "mock-adapter") {
        self.id = id
    }

    func start(onEvent: @escaping @Sendable (AgentEvent) -> Void) {
        self.handler = onEvent
    }

    func stop() {
        self.handler = nil
    }

    func emit(_ event: AgentEvent) {
        handler?(event)
    }
}

@MainActor
final class AgentMonitorServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clean up UserDefaults keys used in tests
        UserDefaults.standard.removeObject(forKey: "Bitz.AgentMonitor.CustomAgents")
        UserDefaults.standard.removeObject(forKey: "Bitz.AgentMonitor.PopupsEnabled")
        for def in AgentDefinition.builtInCatalog {
            UserDefaults.standard.removeObject(forKey: "Bitz.AgentMonitor.Disabled." + def.id)
        }
    }

    func testBuiltInCatalogContainsRequiredAgents() {
        let service = AgentMonitorService()
        let catalog = service.catalog

        let expectedIDs = ["claude", "gemini", "antigravity", "codex", "cursor", "windsurf", "copilot", "aider", "goose", "opencode", "amp", "cline"]
        for expected in expectedIDs {
            XCTAssertTrue(catalog.contains(where: { $0.id == expected }), "Catalog should contain \(expected)")
        }
    }

    func testCustomAgentAddAndRemovePersistence() {
        let service = AgentMonitorService()
        XCTAssertEqual(service.catalog.filter { $0.isCustom }.count, 0)

        service.addCustomAgent(displayName: "MyAgent", processNames: ["my-agent-cli"], bundleIdentifiers: ["com.test.myagent"])
        XCTAssertEqual(service.catalog.filter { $0.isCustom }.count, 1)
        guard let custom = service.catalog.first(where: { $0.displayName == "MyAgent" }) else {
            XCTFail("Custom agent was not added")
            return
        }
        XCTAssertTrue(custom.isCustom)
        XCTAssertTrue(custom.matches(processName: "my-agent-cli"))
        XCTAssertTrue(custom.matches(bundleIdentifier: "com.test.myagent"))

        service.removeCustomAgent(id: custom.id)
        XCTAssertEqual(service.catalog.filter { $0.isCustom }.count, 0)
    }

    func testEnableDisableAgent() {
        let service = AgentMonitorService()
        XCTAssertTrue(service.isAgentEnabled(id: "claude"))

        service.setAgentEnabled(id: "claude", isEnabled: false)
        XCTAssertFalse(service.isAgentEnabled(id: "claude"))

        // An event from a disabled agent should be ignored
        let mock = MockAgentAdapter()
        let testService = AgentMonitorService(adapters: [mock])
        testService.setAgentEnabled(id: "claude", isEnabled: false)
        testService.startMonitoring()

        let event = AgentEvent(
            agentID: "claude",
            agentName: "Claude",
            kind: .needsApproval,
            message: "Need permission"
        )
        testService.handleEvent(event)
        XCTAssertNil(testService.activePopup)
        XCTAssertFalse(testService.activeAgents.contains("claude"))
    }

    func testEventStalenessOverSixtySecondsIsDiscarded() {
        let simulatedNow = Date()
        let service = AgentMonitorService(clock: { simulatedNow })

        let staleTimestamp = simulatedNow.addingTimeInterval(-65.0)
        let staleEvent = AgentEvent(
            agentID: "gemini",
            agentName: "Gemini",
            kind: .done,
            timestamp: staleTimestamp
        )

        service.handleEvent(staleEvent)
        XCTAssertNil(service.activePopup, "Stale event older than 60s should be discarded")
    }

    func testNeedsApprovalPopupPersistsIndefinitelyUntilNextEvent() {
        let fixedDate = Date(timeIntervalSince1970: 1000)
        let service = AgentMonitorService(clock: { fixedDate })

        let approvalEvent = AgentEvent(
            agentID: "antigravity",
            agentName: "Antigravity",
            kind: .needsApproval,
            message: "Run bash command?",
            timestamp: fixedDate
        )

        service.handleEvent(approvalEvent)
        XCTAssertNotNil(service.activePopup)
        XCTAssertEqual(service.activePopup?.kind, .needsApproval)
        XCTAssertEqual(service.activePopup?.text, "Run bash command?")
        XCTAssertNil(service.activePopup?.expiresAt, "Approval popup should not expire automatically")
        XCTAssertTrue(service.activeAgents.contains("antigravity"))

        // Next event (done) updates and sets auto-dismiss
        let doneEvent = AgentEvent(
            agentID: "antigravity",
            agentName: "Antigravity",
            kind: .done,
            message: "All done!",
            timestamp: fixedDate
        )
        service.handleEvent(doneEvent)
        XCTAssertEqual(service.activePopup?.kind, .done)
        XCTAssertEqual(service.activePopup?.text, "All done!")
        XCTAssertNotNil(service.activePopup?.expiresAt, "Done popup must have an expiration")
        XCTAssertFalse(service.activeAgents.contains("antigravity"))
    }

    func testDoneEventAutoDismissLifetime() async {
        let fixedDate = Date(timeIntervalSince1970: 2000)
        let service = AgentMonitorService(clock: { fixedDate })

        let doneEvent = AgentEvent(
            agentID: "claude",
            agentName: "Claude",
            kind: .done,
            timestamp: fixedDate
        )
        service.handleEvent(doneEvent)
        guard let popup = service.activePopup else {
            XCTFail("Popup should be present")
            return
        }

        XCTAssertEqual(popup.kind, .done)
        XCTAssertEqual(popup.text, "Claude is done!")
        XCTAssertEqual(popup.expiresAt?.timeIntervalSince(fixedDate), 6.0)
    }

    func testPopupsDisabledOptionSuppressesPopups() {
        let service = AgentMonitorService()
        service.popupsEnabled = false

        let event = AgentEvent(
            agentID: "codex",
            agentName: "Codex",
            kind: .done
        )
        service.handleEvent(event)
        XCTAssertNil(service.activePopup)
    }
}
