import XCTest
@testable import BitzCore

final class AgentHookInstallerTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testClaudeSettingsSnippetGeneratesValidStructure() {
        let snippet = AgentHookInstaller.claudeSettingsSnippet()
        guard let hooks = snippet["hooks"] as? [String: Any] else {
            XCTFail("Missing hooks dictionary")
            return
        }

        XCTAssertNotNil(hooks["Stop"])
        XCTAssertNotNil(hooks["PermissionRequest"])
        XCTAssertNotNil(hooks["Notification"])

        // Check matcher + hooks nested structure expected by Claude Code
        guard let stopList = hooks["Stop"] as? [[String: Any]],
              let firstStop = stopList.first,
              let innerHooks = firstStop["hooks"] as? [[String: Any]],
              let command = innerHooks.first?["command"] as? String else {
            XCTFail("Stop hook is missing matcher + hooks array structure")
            return
        }
        XCTAssertTrue(command.contains("printf"))
        XCTAssertTrue(command.contains("Claude is done!"))
    }

    func testDropEventScriptGeneration() {
        let script = AgentHookInstaller.dropEventScript(
            agentID: "test-agent",
            agentName: "TestAgent",
            kind: "working",
            message: "Doing work"
        )
        XCTAssertTrue(script.contains("agent-events"))
        XCTAssertTrue(script.contains("test-agent"))
        XCTAssertTrue(script.contains("Doing work"))
        XCTAssertTrue(script.contains("printf"))
    }

    func testHookCommandProducesDecodableAgentEvent() throws {
        let snippet = AgentHookInstaller.claudeSettingsSnippet()
        guard let hooks = snippet["hooks"] as? [String: Any],
              let stopList = hooks["Stop"] as? [[String: Any]],
              let innerHooks = stopList.first?["hooks"] as? [[String: Any]],
              let command = innerHooks.first?["command"] as? String else {
            XCTFail("Could not extract Stop command")
            return
        }

        let tempEventDir = tempDir.appendingPathComponent("agent-events")
        try FileManager.default.createDirectory(at: tempEventDir, withIntermediateDirectories: true)

        // Substitute drop directory with tempEventDir for deterministic testing
        let testCommand = command.replacingOccurrences(
            of: DropboxAgentAdapter.defaultDirectoryURL.path,
            with: tempEventDir.path
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", testCommand]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let files = try FileManager.default.contentsOfDirectory(at: tempEventDir, includingPropertiesForKeys: nil)
        let jsonFiles = files.filter { $0.pathExtension.lowercased() == "json" }
        XCTAssertEqual(jsonFiles.count, 1)

        guard let firstFile = jsonFiles.first,
              let data = try? Data(contentsOf: firstFile) else {
            XCTFail("Generated JSON file could not be read")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgentEvent.self, from: data)
        XCTAssertEqual(event.agentID, "claude")
        XCTAssertEqual(event.agentName, "Claude")
        XCTAssertEqual(event.kind, .done)
        XCTAssertEqual(event.message, "Claude is done!")
    }

    func testBackupFileCreatesCopy() throws {
        let testFile = tempDir.appendingPathComponent("test.json")
        try "initial content".write(to: testFile, atomically: true, encoding: .utf8)

        let backup = try AgentHookInstaller.backupFile(at: testFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
        let content = try String(contentsOf: backup, encoding: .utf8)
        XCTAssertEqual(content, "initial content")
    }
}
