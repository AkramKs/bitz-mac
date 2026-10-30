import XCTest
@testable import BitzCore

final class AntigravityTranscriptAdapterTests: XCTestCase {
    var tempBrainDir: URL!
    var sessionLogsDir: URL!
    var transcriptFile: URL!

    override func setUp() {
        super.setUp()
        tempBrainDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        sessionLogsDir = tempBrainDir.appendingPathComponent("session-1/.system_generated/logs")
        try? FileManager.default.createDirectory(at: sessionLogsDir, withIntermediateDirectories: true)
        transcriptFile = sessionLogsDir.appendingPathComponent("transcript.jsonl")
        FileManager.default.createFile(atPath: transcriptFile.path, contents: Data())
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempBrainDir)
        super.tearDown()
    }

    func testDetectsAntigravityTurnEvents() throws {
        let adapter = AntigravityTranscriptAdapter(baseBrainURL: tempBrainDir)

        final class Collector: @unchecked Sendable {
            var events: [AgentEvent] = []
            let lock = NSLock()
            func append(_ e: AgentEvent) { lock.lock(); events.append(e); lock.unlock() }
            var snapshot: [AgentEvent] { lock.lock(); defer { lock.unlock() }; return events }
        }

        let collector = Collector()
        adapter.setHandlerForTesting { collector.append($0) }

        // Start adapter (it sets offset to current EOF)
        adapter.start { collector.append($0) }

        let handle = try FileHandle(forWritingTo: transcriptFile)
        defer { try? handle.close() }

        // 1. User Input Line -> .working
        let userLine = "{\"step_index\":1,\"source\":\"USER_EXPLICIT\",\"type\":\"USER_INPUT\",\"status\":\"DONE\",\"content\":\"hello\"}\n"
        handle.seekToEndOfFile()
        handle.write(userLine.data(using: .utf8)!)

        adapter.checkForUpdates()
        XCTAssertEqual(collector.snapshot.count, 1)
        XCTAssertEqual(collector.snapshot.first?.kind, .working)
        XCTAssertEqual(collector.snapshot.first?.agentID, "antigravity")

        // 2. Question / Approval -> .needsApproval (flat format as actually written by Antigravity)
        let questionLine = "{\"step_index\":2,\"source\":\"MODEL\",\"type\":\"PLANNER_RESPONSE\",\"status\":\"DONE\",\"tool_calls\":[{\"name\":\"ask_question\",\"args\":{}}]}\n"
        handle.seekToEndOfFile()
        handle.write(questionLine.data(using: .utf8)!)

        adapter.checkForUpdates()
        XCTAssertEqual(collector.snapshot.count, 2)
        XCTAssertEqual(collector.snapshot.last?.kind, .needsApproval)

        // 2b. Legacy / nested format support -> .needsApproval
        let legacyQuestionLine = "{\"step_index\":2,\"source\":\"MODEL\",\"type\":\"PLANNER_RESPONSE\",\"status\":\"DONE\",\"tool_calls\":[{\"id\":\"c1\",\"type\":\"function\",\"function\":{\"name\":\"ask_question\",\"arguments\":\"{}\"}}]}\n"
        handle.seekToEndOfFile()
        handle.write(legacyQuestionLine.data(using: .utf8)!)

        adapter.checkForUpdates()
        XCTAssertEqual(collector.snapshot.count, 3)
        XCTAssertEqual(collector.snapshot.last?.kind, .needsApproval)

        // 3. Final Model Response -> .done
        let doneLine = "{\"step_index\":3,\"source\":\"MODEL\",\"type\":\"PLANNER_RESPONSE\",\"status\":\"DONE\",\"content\":\"Here is the response!\"}\n"
        handle.seekToEndOfFile()
        handle.write(doneLine.data(using: .utf8)!)

        adapter.checkForUpdates()
        XCTAssertEqual(collector.snapshot.count, 4)
        XCTAssertEqual(collector.snapshot.last?.kind, .done)
        XCTAssertEqual(collector.snapshot.last?.message, "Antigravity is done!")

        adapter.stop()
    }
}
