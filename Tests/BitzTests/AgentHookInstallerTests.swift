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

    // MARK: - settings.json merge

    private let userGroup: [String: Any] = [
        "matcher": "",
        "hooks": [["type": "command", "command": "echo mine"]]
    ]

    private func commands(_ settings: [String: Any], _ event: String) -> [String] {
        let groups = (settings["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
        return groups.flatMap { ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String } }
    }

    private func isBitz(_ command: String) -> Bool {
        let snippet = AgentHookInstaller.claudeSettingsSnippet()
        return ["Stop", "PermissionRequest", "Notification"].flatMap { commands(snippet, $0) }.contains(command)
    }

    private func group(_ command: String) -> [String: Any] {
        ["matcher": "", "hooks": [["type": "command", "command": command]]]
    }

    func testInstallPreservesUserHooksAndOtherKeys() throws {
        let settings: [String: Any] = ["model": "opus", "hooks": ["Stop": [userGroup]]]

        let result = try AgentHookInstaller.installClaudeHooks(in: settings)

        XCTAssertEqual(result["model"] as? String, "opus")
        let stop = commands(result, "Stop")
        XCTAssertEqual(stop.count, 2)
        XCTAssertEqual(stop.first, "echo mine")
        XCTAssertTrue(isBitz(stop[1]))
        XCTAssertEqual(commands(result, "PermissionRequest").filter(isBitz).count, 1)
        XCTAssertEqual(commands(result, "Notification").filter(isBitz).count, 1)
    }

    func testInstallIsIdempotent() throws {
        let once = try AgentHookInstaller.installClaudeHooks(in: ["hooks": ["Stop": [userGroup]]])
        let twice = try AgentHookInstaller.installClaudeHooks(in: once)

        XCTAssertEqual(NSDictionary(dictionary: twice), NSDictionary(dictionary: once))
        XCTAssertEqual(commands(twice, "Stop").count, 2)
    }

    func testUninstallRemovesOnlyBitzEntries() throws {
        var settings = try AgentHookInstaller.installClaudeHooks(in: ["model": "opus", "hooks": ["Stop": [userGroup]]])
        // A group where the user put their own command next to Bitz's
        var hooks = settings["hooks"] as! [String: Any]
        let bitzCommand = commands(settings, "Notification")[0]
        hooks["Notification"] = [[
            "matcher": "",
            "hooks": [["type": "command", "command": "echo other"], ["type": "command", "command": bitzCommand]]
        ]]
        settings["hooks"] = hooks

        let result = try AgentHookInstaller.uninstallClaudeHooks(from: settings)

        XCTAssertEqual(result["model"] as? String, "opus")
        XCTAssertEqual(commands(result, "Stop"), ["echo mine"])
        XCTAssertEqual(commands(result, "Notification"), ["echo other"])
        XCTAssertNil((result["hooks"] as? [String: Any])?["PermissionRequest"])
    }

    func testUserDropboxHooksAreNotTreatedAsBitz() throws {
        let working = AgentHookInstaller.dropEventScript(agentID: "claude", agentName: "Claude", kind: "working", message: "On it")
        let waiting = AgentHookInstaller.dropEventScript(agentID: "claude", agentName: "Claude", kind: "needsApproval", message: "Mine")
        let settings: [String: Any] = ["hooks": ["UserPromptSubmit": [group(working)], "Notification": [group(waiting)]]]

        let installed = try AgentHookInstaller.installClaudeHooks(in: settings)
        let notification = commands(installed, "Notification")
        XCTAssertEqual(notification.count, 2)
        XCTAssertEqual(notification.first, waiting)
        XCTAssertTrue(isBitz(notification[1]))

        let result = try AgentHookInstaller.uninstallClaudeHooks(from: installed)
        XCTAssertEqual(commands(result, "UserPromptSubmit"), [working])
        XCTAssertEqual(commands(result, "Notification"), [waiting])
        XCTAssertNil((result["hooks"] as? [String: Any])?["Stop"])
    }

    func testUninstallLeavesFileUnchangedWithoutBitzEntries() throws {
        let file = tempDir.appendingPathComponent("settings.json")
        let original = #"{"z": 1, "hooks": {"Stop": [{"matcher": "", "hooks": [{"type": "command", "command": "/usr/bin/true"}]}], "PreToolUse": []}}"#
        try original.write(to: file, atomically: true, encoding: .utf8)

        try AgentHookInstaller.updateSettingsFile(at: file, AgentHookInstaller.uninstallClaudeHooks)

        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), original)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: tempDir.path), ["settings.json"])
    }

    func testInstallCreatesMissingFileWithoutEscapedSlashes() throws {
        let file = tempDir.appendingPathComponent(".claude/settings.json")

        try AgentHookInstaller.updateSettingsFile(at: file, AgentHookInstaller.installClaudeHooks)

        let written = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(written.contains("Bitz/agent-events"))
        XCTAssertFalse(written.contains(#"\/"#))
    }

    func testInvalidSettingsAbortWithoutWriting() throws {
        let file = tempDir.appendingPathComponent("settings.json")
        for original in ["not json {", "[1, 2]", #"{"hooks": []}"#, #"{"hooks": {"Stop": "oops"}}"#] {
            try original.write(to: file, atomically: true, encoding: .utf8)

            for transform in [AgentHookInstaller.installClaudeHooks, AgentHookInstaller.uninstallClaudeHooks] {
                XCTAssertThrowsError(try AgentHookInstaller.updateSettingsFile(at: file, transform), original) { error in
                    XCTAssertTrue(error.localizedDescription.contains("settings.json"), error.localizedDescription)
                }
            }
            XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), original)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: tempDir.path), ["settings.json"])
    }

    func testBackupOfSymlinkedSettingsCopiesTarget() throws {
        let real = tempDir.appendingPathComponent("real.json")
        let link = tempDir.appendingPathComponent("settings.json")
        let original = #"{"model": "opus"}"#
        try original.write(to: real, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        try AgentHookInstaller.updateSettingsFile(at: link, AgentHookInstaller.installClaudeHooks)

        let backupName = try XCTUnwrap(try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .first { $0.hasPrefix("settings.json.bitz-backup") })
        let backup = tempDir.appendingPathComponent(backupName)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: backup.path)[.type] as? FileAttributeType, .typeRegular)
        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), original)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType, .typeSymbolicLink)
        XCTAssertTrue(try String(contentsOf: real, encoding: .utf8).contains("Bitz/agent-events"))
    }

    func testFailedBackupAbortsWithoutWriting() throws {
        let real = tempDir.appendingPathComponent("real.json")
        let lockedDir = tempDir.appendingPathComponent("locked")
        let link = lockedDir.appendingPathComponent("settings.json")
        let original = #"{"model": "opus"}"#
        try original.write(to: real, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: lockedDir, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        // The backup goes next to the link in a read-only dir and fails; the write to the target would still succeed.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: lockedDir.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: lockedDir.path) }

        XCTAssertThrowsError(try AgentHookInstaller.updateSettingsFile(at: link, AgentHookInstaller.installClaudeHooks))
        XCTAssertEqual(try String(contentsOf: real, encoding: .utf8), original)
    }

    func testDanglingSymlinkAbortsWithoutReplacingLink() throws {
        let link = tempDir.appendingPathComponent("settings.json")
        let destination = tempDir.appendingPathComponent("missing.json").path
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: destination)

        XCTAssertThrowsError(try AgentHookInstaller.updateSettingsFile(at: link, AgentHookInstaller.installClaudeHooks)) { error in
            XCTAssertTrue(error.localizedDescription.contains("settings.json"), error.localizedDescription)
        }
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), destination)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: tempDir.path), ["settings.json"])
    }

    func testReadOnlySettingsAbortWithoutWriting() throws {
        let file = tempDir.appendingPathComponent("settings.json")
        let original = #"{"model": "opus"}"#
        try original.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path) }

        XCTAssertThrowsError(try AgentHookInstaller.updateSettingsFile(at: file, AgentHookInstaller.installClaudeHooks)) { error in
            XCTAssertTrue(error.localizedDescription.contains("settings.json"), error.localizedDescription)
        }
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), original)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int, 0o444)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: tempDir.path), ["settings.json"])
    }

    func testBackToBackUpdatesKeepBackupsAndFileMode() throws {
        let file = tempDir.appendingPathComponent("settings.json")
        try #"{"model": "opus"}"#.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)

        try AgentHookInstaller.updateSettingsFile(at: file, AgentHookInstaller.installClaudeHooks)
        try AgentHookInstaller.updateSettingsFile(at: file, AgentHookInstaller.uninstallClaudeHooks)

        let backups = try FileManager.default.contentsOfDirectory(atPath: tempDir.path).filter { $0.hasPrefix("settings.json.bitz-backup.") }
        XCTAssertEqual(backups.count, 2)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int, 0o600)
    }
}
