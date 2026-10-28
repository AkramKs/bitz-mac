import Foundation

/// Safe, reversible installer for configuring agent hooks into the drop-box directory.
public struct AgentHookInstaller {

    public enum HookType: String, CaseIterable, Sendable {
        case claudeCode
        case codex
    }

    public static func dropEventScript(agentID: String, agentName: String, kind: String, message: String) -> String {
        let dir = DropboxAgentAdapter.defaultDirectoryURL.path
        let cleanID = agentID.replacingOccurrences(of: "'", with: "")
        let cleanName = agentName.replacingOccurrences(of: "'", with: "")
        let cleanKind = kind.replacingOccurrences(of: "'", with: "")
        let cleanMessage = message.replacingOccurrences(of: "'", with: "")
        return """
        mkdir -p '\(dir)' && id=$(uuidgen | tr '[:upper:]' '[:lower:]') && ts=$(date -u +%Y-%m-%dT%H:%M:%SZ) && printf '{"id":"%s","agentID":"%s","agentName":"%s","kind":"%s","message":"%s","timestamp":"%s"}\\n' "$id" '\(cleanID)' '\(cleanName)' '\(cleanKind)' '\(cleanMessage)' "$ts" > '\(dir)/'$id.json
        """
    }

    /// Generates Claude Code notification/stop hooks snippet for ~/.claude/settings.json
    public static func claudeSettingsSnippet() -> [String: Any] {
        let dir = DropboxAgentAdapter.defaultDirectoryURL.path
        let doneCommand = "mkdir -p '\(dir)' && id=$(uuidgen | tr '[:upper:]' '[:lower:]') && ts=$(date -u +%Y-%m-%dT%H:%M:%SZ) && printf '{\"id\":\"%s\",\"agentID\":\"%s\",\"agentName\":\"%s\",\"kind\":\"%s\",\"message\":\"%s\",\"timestamp\":\"%s\"}\\n' \"$id\" \"claude\" \"Claude\" \"done\" \"Claude is done!\" \"$ts\" > '\(dir)/'$id.json"

        let approvalCommand = "mkdir -p '\(dir)' && id=$(uuidgen | tr '[:upper:]' '[:lower:]') && ts=$(date -u +%Y-%m-%dT%H:%M:%SZ) && printf '{\"id\":\"%s\",\"agentID\":\"%s\",\"agentName\":\"%s\",\"kind\":\"%s\",\"message\":\"%s\",\"timestamp\":\"%s\"}\\n' \"$id\" \"claude\" \"Claude\" \"needsApproval\" \"Claude needs approval!\" \"$ts\" > '\(dir)/'$id.json"

        let stopHook: [String: Any] = [
            "matcher": "",
            "hooks": [
                ["type": "command", "command": doneCommand]
            ]
        ]

        let approvalHook: [String: Any] = [
            "matcher": "",
            "hooks": [
                ["type": "command", "command": approvalCommand]
            ]
        ]

        return [
            "hooks": [
                "Stop": [stopHook],
                "PermissionRequest": [approvalHook],
                "Notification": [approvalHook]
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
