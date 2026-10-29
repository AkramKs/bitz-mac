import SwiftUI
import AppKit

/// Settings tab for configuring hardware sensor metrics, display placements, sampling interval, and alert thresholds.
public struct TelemetrySettingsTabView: View {
    @ObservedObject public var telemetryDashboard: TelemetryDashboardService
    @ObservedObject public var telemetrySettings: TelemetrySettingsStore

    public init(
        telemetryDashboard: TelemetryDashboardService,
        telemetrySettings: TelemetrySettingsStore
    ) {
        self.telemetryDashboard = telemetryDashboard
        self.telemetrySettings = telemetrySettings
    }

    public var body: some View {
        Form {
            // MARK: - Display Placements
            Section("Telemetry Display Locations") {
                Toggle("Compact Menu Bar Title Item", isOn: $telemetrySettings.displayInMenuBarTitle)
                Toggle("Mascot Floating Cyber HUD", isOn: $telemetrySettings.displayInMascotCyberHUD)
                Toggle("Speech Bubble Carousel", isOn: $telemetrySettings.displayInSpeechBubbleCycle)
                Toggle("Show in Menu Bar Dropdown", isOn: $telemetrySettings.displayInMenuBarMenu)
            }

            // MARK: - Visible Metrics
            Section("Monitored Metrics") {
                ForEach(TelemetryMetric.allCases) { metric in
                    Toggle(metric.displayName, isOn: Binding(
                        get: { telemetrySettings.isMetricEnabled(metric) },
                        set: { telemetrySettings.setMetric(metric, enabled: $0) }
                    ))
                }
            }

            // MARK: - Cadence & Thresholds
            Section("Sampling Cadence & Warning Limits") {
                Picker("Update Interval", selection: $telemetrySettings.pollingIntervalSeconds) {
                    Text("1 second").tag(1.0)
                    Text("3 seconds").tag(3.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                }

                Picker("Low Disk Space Alert", selection: $telemetrySettings.lowDiskWarningThresholdPercent) {
                    Text("Warn below 5%").tag(5.0)
                    Text("Warn below 10%").tag(10.0)
                    Text("Warn below 15%").tag(15.0)
                    Text("Warn below 20%").tag(20.0)
                }

                Button("Refresh Telemetry Now") {
                    Task {
                        await telemetryDashboard.performSampleTick()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
