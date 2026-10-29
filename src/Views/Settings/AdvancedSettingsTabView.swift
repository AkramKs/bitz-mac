import SwiftUI
import AppKit
import ServiceManagement

/// Settings tab for diagnostic state simulations, keyboard shortcut cheatsheet, update settings, and system lifecycle.
public struct AdvancedSettingsTabView: View {
    @ObservedObject public var engine: WellnessPointEngine
    @ObservedObject public var activityMonitor: ActivityMonitorService
    @ObservedObject public var updateStore: AppUpdateStore

    @State private var launchAtLoginEnabled: Bool = (SMAppService.mainApp.status == .enabled)

    public init(
        engine: WellnessPointEngine,
        activityMonitor: ActivityMonitorService,
        updateStore: AppUpdateStore
    ) {
        self.engine = engine
        self.activityMonitor = activityMonitor
        self.updateStore = updateStore
    }

    public var body: some View {
        Form {
            // MARK: - State Simulation & Testing
            Section("Behavior State Simulation 🧪") {
                VStack(alignment: .leading, spacing: 8) {
                    if activityMonitor.isManualOverrideActive {
                        Button("Disable Override (Resume Live Sensors)") {
                            activityMonitor.clearManualOverride()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    HStack {
                        Button("Super Charged (90 PTS)") {
                            activityMonitor.isManualOverrideActive = true
                            engine.setPoints(90.0, continuousWorkMinutes: 10.0)
                        }
                        Button("Balanced (50 PTS)") {
                            activityMonitor.isManualOverrideActive = true
                            engine.setPoints(50.0, continuousWorkMinutes: 0.0)
                        }
                        Button("Sad / Overload (20 PTS)") {
                            activityMonitor.isManualOverrideActive = true
                            engine.setPoints(20.0, continuousWorkMinutes: 0.0)
                        }
                    }

                    HStack {
                        Button("Overworked (50m)") {
                            activityMonitor.isManualOverrideActive = true
                            engine.setPoints(75.0, continuousWorkMinutes: 50.0)
                        }
                        Button("Burnout (95m)") {
                            activityMonitor.isManualOverrideActive = true
                            engine.setPoints(75.0, continuousWorkMinutes: 95.0)
                        }
                        Button("Charging Mode ⚡") {
                            activityMonitor.isManualOverrideActive = true
                            engine.setChargingState(true)
                        }
                    }
                }
            }

            // MARK: - Keyboard Shortcuts Reference
            Section("Keyboard Shortcuts ⌨️") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("• ⌥ Option + Click & Drag: Move mascot anywhere")
                    Text("• ⎋ Escape or Right-Click: Lock position")
                    Text("• P: Pet Bitz")
                    Text("• ⌘, : Open Settings Window")
                    Text("• ⌘- / ⌘= : Scale avatar smaller / larger")
                    Text("• ⌘[ / ⌘] : Decrease / increase opacity")
                    Text("• ⌘Q: Quit Bitz")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            // MARK: - System Lifecycle & Updates
            Section("System & Updates") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLoginEnabled },
                    set: { shouldEnable in
                        do {
                            if shouldEnable {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                            launchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
                        } catch {
                            launchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
                        }
                    }
                ))

                Toggle("Check for Updates Automatically", isOn: $updateStore.automaticallyCheckForUpdates)

                HStack {
                    Button("Check for Updates Now") {
                        Task {
                            await updateStore.checkForUpdates(manual: true)
                        }
                    }
                    Text(updateStore.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
