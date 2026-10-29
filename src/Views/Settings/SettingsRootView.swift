import SwiftUI
import AppKit

/// Root container for the Bitz Settings window, organizing configuration into native macOS tabs.
public struct SettingsRootView: View {
    @ObservedObject public var engine: WellnessPointEngine
    @ObservedObject public var activityMonitor: ActivityMonitorService
    @ObservedObject public var scaleStore: AvatarScaleStore
    @ObservedObject public var opacityStore: AvatarOpacityStore
    @ObservedObject public var positionStore: AvatarPositionStore
    @ObservedObject public var displayStore: DisplayPreferenceStore
    @ObservedObject public var agentMonitor: AgentMonitorService
    @ObservedObject public var updateStore: AppUpdateStore
    @ObservedObject public var telemetryDashboard: TelemetryDashboardService
    @ObservedObject public var telemetrySettings: TelemetrySettingsStore

    public init(
        engine: WellnessPointEngine,
        activityMonitor: ActivityMonitorService,
        scaleStore: AvatarScaleStore,
        opacityStore: AvatarOpacityStore,
        positionStore: AvatarPositionStore,
        displayStore: DisplayPreferenceStore,
        agentMonitor: AgentMonitorService,
        updateStore: AppUpdateStore,
        telemetryDashboard: TelemetryDashboardService,
        telemetrySettings: TelemetrySettingsStore
    ) {
        self.engine = engine
        self.activityMonitor = activityMonitor
        self.scaleStore = scaleStore
        self.opacityStore = opacityStore
        self.positionStore = positionStore
        self.displayStore = displayStore
        self.agentMonitor = agentMonitor
        self.updateStore = updateStore
        self.telemetryDashboard = telemetryDashboard
        self.telemetrySettings = telemetrySettings
    }

    public var body: some View {
        TabView {
            GeneralSettingsTabView(
                scaleStore: scaleStore,
                opacityStore: opacityStore,
                positionStore: positionStore,
                displayStore: displayStore
            )
            .tabItem {
                Label("General", systemImage: "paintbrush")
            }

            BehaviorSettingsTabView(
                engine: engine,
                activityMonitor: activityMonitor
            )
            .tabItem {
                Label("Behaviors", systemImage: "pawprint.fill")
            }

            AgentsSettingsTabView(
                agentMonitor: agentMonitor
            )
            .tabItem {
                Label("AI Agents", systemImage: "cpu")
            }

            TelemetrySettingsTabView(
                telemetryDashboard: telemetryDashboard,
                telemetrySettings: telemetrySettings
            )
            .tabItem {
                Label("Telemetry", systemImage: "chart.xyaxis.line")
            }

            AdvancedSettingsTabView(
                engine: engine,
                activityMonitor: activityMonitor,
                updateStore: updateStore
            )
            .tabItem {
                Label("Advanced", systemImage: "wrench.and.screwdriver")
            }
        }
        .frame(minWidth: 540, minHeight: 460)
    }
}
