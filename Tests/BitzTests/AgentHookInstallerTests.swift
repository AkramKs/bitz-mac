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
        XCTAssertNotNil(hooks["Notification"])
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
