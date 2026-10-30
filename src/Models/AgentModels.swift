import Foundation

/// Defines the kind of lifecycle / activity event emitted by an AI agent.
public enum AgentEventKind: String, Codable, Sendable, CaseIterable {
    case started
    case working
    case needsApproval
    case done
}

/// A structured event emitted by an agent adapter when an agent state transition occurs.
public struct AgentEvent: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let agentID: String
    public let agentName: String
    public let kind: AgentEventKind
    public let message: String?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        agentID: String,
        agentName: String,
        kind: AgentEventKind,
        message: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.agentID = agentID
        self.agentName = agentName
        self.kind = kind
        self.message = message
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case id
        case agentID
        case agentName
        case kind
        case message
        case timestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let uuidString = try? container.decode(String.self, forKey: .id),
           let parsedUUID = UUID(uuidString: uuidString) {
            self.id = parsedUUID
        } else if let uuid = try? container.decode(UUID.self, forKey: .id) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        self.agentID = try container.decode(String.self, forKey: .agentID)
        self.agentName = try container.decode(String.self, forKey: .agentName)
        self.kind = try container.decode(AgentEventKind.self, forKey: .kind)
        self.message = try? container.decode(String.self, forKey: .message)
        self.timestamp = (try? container.decode(Date.self, forKey: .timestamp)) ?? Date()
    }
}

/// Metadata and matching rules for an AI agent.
public struct AgentDefinition: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let processNames: [String]
    public let bundleIdentifiers: [String]
    public let isCustom: Bool
    public var isEnabled: Bool

    public init(
        id: String,
        displayName: String,
        processNames: [String] = [],
        bundleIdentifiers: [String] = [],
        isCustom: Bool = false,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.processNames = processNames
        self.bundleIdentifiers = bundleIdentifiers
        self.isCustom = isCustom
        self.isEnabled = isEnabled
    }

    /// Checks if a given process name or bundle ID matches this agent definition.
    public func matches(processName: String? = nil, bundleIdentifier: String? = nil) -> Bool {
        // Exclude Apple system bundles (e.g., com.apple.TextInputUI.xpc.CursorUIViewService)
        if let bundle = bundleIdentifier?.lowercased(), bundle.hasPrefix("com.apple.") {
            return false
        }

        if let bundleIdentifier = bundleIdentifier?.lowercased() {
            for bundle in bundleIdentifiers {
                if bundleIdentifier == bundle.lowercased() {
                    return true
                }
            }
        }

        if let processName = processName?.lowercased() {
            for name in processNames {
                let target = name.lowercased()
                if processName == target || processName == "\(target) helper" {
                    return true
                }
            }
        }

        return false
    }

    /// Built-in catalog of supported AI agents out-of-the-box.
    public static var builtInCatalog: [AgentDefinition] {
        [
            AgentDefinition(
                id: "claude",
                displayName: "Claude",
                processNames: ["claude", "claude-code"],
                bundleIdentifiers: ["com.anthropic.claudefordesktop"]
            ),
            AgentDefinition(
                id: "gemini",
                displayName: "Gemini",
                processNames: ["gemini"],
                bundleIdentifiers: ["com.google.GeminiMacOS"]
            ),
            AgentDefinition(
                id: "antigravity",
                displayName: "Antigravity",
                processNames: ["antigravity", "agy"],
                bundleIdentifiers: ["com.google.antigravity", "com.google.antigravity-ide"]
            ),
            AgentDefinition(
                id: "codex",
                displayName: "Codex / ChatGPT",
                processNames: ["codex"],
                bundleIdentifiers: ["com.openai.chat"]
            ),
            AgentDefinition(
                id: "cursor",
                displayName: "Cursor",
                processNames: ["cursor"],
                bundleIdentifiers: ["com.todesktop.230313mzl4w4u92"]
            ),
            AgentDefinition(
                id: "windsurf",
                displayName: "Windsurf",
                processNames: ["windsurf"],
                bundleIdentifiers: ["com.exafunction.windsurf"]
            ),
            AgentDefinition(
                id: "copilot",
                displayName: "GitHub Copilot",
                processNames: ["copilot", "github-copilot"],
                bundleIdentifiers: ["com.microsoft.VSCode"]
            ),
            AgentDefinition(
                id: "aider",
                displayName: "Aider",
                processNames: ["aider"]
            ),
            AgentDefinition(
                id: "goose",
                displayName: "Goose",
                processNames: ["goose"]
            ),
            AgentDefinition(
                id: "opencode",
                displayName: "OpenCode",
                processNames: ["opencode"]
            ),
            AgentDefinition(
                id: "amp",
                displayName: "Amp",
                processNames: ["amp"]
            ),
            AgentDefinition(
                id: "cline",
                displayName: "Cline / Roo",
                processNames: ["cline", "roo-cline"]
            )
        ]
    }
}

/// Represents the visual popup notification shown on the MascotOverlay.
public struct AgentPopupState: Sendable, Equatable {
    public let text: String
    public let kind: AgentEventKind
    public let agentName: String
    public let expiresAt: Date?

    public init(text: String, kind: AgentEventKind, agentName: String, expiresAt: Date?) {
        self.text = text
        self.kind = kind
        self.agentName = agentName
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }
}
