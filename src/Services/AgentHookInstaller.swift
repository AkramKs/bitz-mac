import Foundation

/// Safe, reversible installer for configuring agent hooks into the drop-box directory.
public struct AgentHookInstaller {

    public enum HookType: String, CaseIterable, Sendable {
        case claudeCode
        case codex
    }

    public static func dropEventScript(agentID: String, agentName: String, kind: String, message: String) -> String {
        let dir = DropboxAgentAdapter.defaultDirectoryURL.path
        return """
        mkdir -p '\(dir)' && ts=$(date -u +%Y-%m-%dT%H:%M:%SZ) && id=$(uuidgen | tr '[:upper:]' '[:lower:]') && cat << 'EOF' > '\(dir)/'$id.json
        {"id":"$id","agentID":"\(agentID)","agentName":"\(agentName)","kind":"\(kind)","message":"\(message)","timestamp":"$ts"}
        EOF
        """
    }

    /// Generates Claude Code notification/stop hooks snippet for ~/.claude/settings.json
    public static func claudeSettingsSnippet() -> [String: Any] {
        let doneCommand = "mkdir -p '\(DropboxAgentAdapter.defaultDirectoryURL.path)' && ts=$(date -u +%Y-%m-%dT%H:%M:%SZ) && id=$(uuidgen) && echo '{\"agentID\":\"claude\",\"agentName\":\"Claude\",\"kind\":\"done\",\"message\":\"Claude is done!\",\"timestamp\":\"'\"$ts\"'\"}' > '\(DropboxAgentAdapter.defaultDirectoryURL.path)/'\"$id\".json"

        let approvalCommand = "mkdir -p '\(DropboxAgentAdapter.defaultDirectoryURL.path)' && ts=$(date -u +%Y-%m-%dT%H:%M:%SZ) && id=$(uuidgen) && echo '{\"agentID\":\"claude\",\"agentName\":\"Claude\",\"kind\":\"needsApproval\",\"message\":\"Claude needs approval!\",\"timestamp\":\"'\"$ts\"'\"}' > '\(DropboxAgentAdapter.defaultDirectoryURL.path)/'\"$id\".json"

        return [
            "hooks": [
                "Stop": [
                    ["type": "command", "command": doneCommand]
                ],
                "Notification": [
                    ["type": "command", "command": approvalCommand]
                ]
            ]
        ]
    }

    /// Backs up a target file before modification.
    public static func backupFile(at url: URL) throws -> URL {
        let backupURL = url.appendingPathExtension("bitz-backup.\(Int(Date().timeIntervalSince1970))")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.copyItem(at: url, to: backupURL)
        }
        return backupURL
    }
}
