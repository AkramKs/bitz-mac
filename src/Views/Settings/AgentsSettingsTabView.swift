import SwiftUI
import AppKit

/// Settings tab for managing AI Coding Agent detection, speech bubble popups, and Claude Code hook installation.
public struct AgentsSettingsTabView: View {
    @ObservedObject public var agentMonitor: AgentMonitorService

    @State private var hookActionMessage: String? = nil
    @State private var isHookActionError: Bool = false

    public init(agentMonitor: AgentMonitorService) {
        self.agentMonitor = agentMonitor
    }

    public var body: some View {
        Form {
            // MARK: - Notifications Section
            Section("Status Popups") {
                Toggle("Show Agent Status Speech Bubbles", isOn: $agentMonitor.popupsEnabled)
                Text("Displays an alert speech bubble when a background AI coding agent finishes a task or requires human approval.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Monitored Agents Catalog
            Section("Monitored Agents (\(agentMonitor.activeAgents.count) Active)") {
                ForEach(agentMonitor.catalog) { agent in
                    Toggle(agent.displayName, isOn: Binding(
                        get: { agent.isEnabled },
                        set: { isEnabled in
                            agentMonitor.setAgentEnabled(id: agent.id, isEnabled: isEnabled)
                        }
                    ))
                }
            }

            // MARK: - Claude Code Hooks Integration
            Section("Claude Code Integration Hooks") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Install hooks to ~/.claude/settings.json for precise, instant completion and approval alerts without process polling delays.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button("Install Claude Hook") {
                            let url = URL(fileURLWithPath: ("~/.claude/settings.json" as NSString).expandingTildeInPath)
                            do {
                                try AgentHookInstaller.updateSettingsFile(at: url, AgentHookInstaller.installClaudeHooks)
                                hookActionMessage = "Claude Code hooks successfully installed!"
                                isHookActionError = false
                            } catch {
                                hookActionMessage = "Failed to install hooks: \(error.localizedDescription)"
                                isHookActionError = true
                            }
                        }

                        Button("Uninstall Claude Hook") {
                            let url = URL(fileURLWithPath: ("~/.claude/settings.json" as NSString).expandingTildeInPath)
                            do {
                                try AgentHookInstaller.updateSettingsFile(at: url, AgentHookInstaller.uninstallClaudeHooks)
                                hookActionMessage = "Claude Code hooks uninstalled."
                                isHookActionError = false
                            } catch {
                                hookActionMessage = "Failed to uninstall: \(error.localizedDescription)"
                                isHookActionError = true
                            }
                        }
                    }

                    if let msg = hookActionMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(isHookActionError ? .red : .green)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
