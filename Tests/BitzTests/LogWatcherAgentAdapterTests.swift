import XCTest
@testable import BitzCore

final class LogWatcherAgentAdapterTests: XCTestCase {
    var tempLogURL: URL!

    override func setUp() {
        super.setUp()
        tempLogURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".log")
        FileManager.default.createFile(atPath: tempLogURL.path, contents: Data())
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempLogURL)
        super.tearDown()
    }

    func testDetectsApprovalAndDoneKeywords() {
        let adapter = LogWatcherAgentAdapter(
            agentID: "antigravity",
            agentName: "Antigravity",
            logFileURL: tempLogURL
        )

        final class Collector: @unchecked Sendable {
            var events: [AgentEvent] = []
            let lock = NSLock()
            func append(_ e: AgentEvent) { lock.lock(); events.append(e); lock.unlock() }
            var snapshot: [AgentEvent] { lock.lock(); defer { lock.unlock() }; return events }
        }

        let collector = Collector()
        adapter.setHandlerForTesting { collector.append($0) }

        // Append approval request line
        let approvalLine = "2026-10-26 [STATE] Tool execution requires user approval.\n"
        let handle = try? FileHandle(forWritingTo: tempLogURL)
        handle?.seekToEndOfFile()
        handle?.write(approvalLine.data(using: .utf8)!)

        adapter.readNewLogLines()
        XCTAssertEqual(collector.snapshot.count, 1)
        XCTAssertEqual(collector.snapshot.first?.kind, .needsApproval)

        // Append done line
        let doneLine = "2026-10-26 [STATE] Mission completed successfully.\n"
        handle?.seekToEndOfFile()
        handle?.write(doneLine.data(using: .utf8)!)
        try? handle?.close()

        adapter.readNewLogLines()
        XCTAssertEqual(collector.snapshot.count, 2)
        XCTAssertEqual(collector.snapshot.last?.kind, .done)
    }
}
