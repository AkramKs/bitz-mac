import SwiftUI
import AppKit

/// Settings tab for customizing mascot behavior rules, wellness scoring, and application classification.
public struct BehaviorSettingsTabView: View {
    @ObservedObject public var engine: WellnessPointEngine
    @ObservedObject public var activityMonitor: ActivityMonitorService

    public init(
        engine: WellnessPointEngine,
        activityMonitor: ActivityMonitorService
    ) {
        self.engine = engine
        self.activityMonitor = activityMonitor
    }

    public var body: some View {
        Form {
            // MARK: - Wellness & Focus Status
            Section("Focus & Health Status") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current State:")
                        Spacer()
                        Text("\(engine.currentState.rawValue) (\(String(format: "%.0f", engine.currentPoints)) PTS)")
                            .bold()
                    }

                    HStack {
                        Text("Focus Streak:")
                        Spacer()
                        Text(String(format: "%.0f min", engine.continuousWorkMinutes))
                            .foregroundStyle(.secondary)
                    }

                    Button("Pet Bitz (<3)") {
                        engine.triggerPetInteraction()
                    }
                    .buttonStyle(.bordered)
                }
            }

            // MARK: - Application Classification Rules
            Section("Application Productivity Classification") {
                VStack(alignment: .leading, spacing: 8) {
                    if let frontmost = activityMonitor.lastFrontmostAppName {
                        let tag = activityMonitor.lastAppIsProductive ? "+0.5 Productive" : "-1.5 Dopamine Drain"
                        let customTag = activityMonitor.frontmostAppCustomRule.map { $0 ? " [Custom: Productive]" : " [Custom: Distraction]" } ?? ""
                        HStack {
                            Text("Active App:")
                            Spacer()
                            Text("\(frontmost) (\(tag))\(customTag)")
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            if activityMonitor.frontmostAppCustomRule != true {
                                Button("Mark as Productive") {
                                    activityMonitor.markFrontmostApp(asProductive: true)
                                }
                            }
                            if activityMonitor.frontmostAppCustomRule != false {
                                Button("Mark as Distraction") {
                                    activityMonitor.markFrontmostApp(asProductive: false)
                                }
                            }
                            if activityMonitor.frontmostAppCustomRule != nil {
                                Button("Reset Rule") {
                                    activityMonitor.resetFrontmostAppRule()
                                }
                            }
                        }
                    } else {
                        Text("No active application detected")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - Idle & Sensors Status
            Section("Hardware & Idle Sensors") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("User Idle Seconds:")
                        Spacer()
                        Text(String(format: "%.0fs", activityMonitor.lastIdleSeconds))
                            .foregroundStyle(.secondary)
                    }

                    if let temp = activityMonitor.lastTemperatureCelsius {
                        HStack {
                            Text("CPU Die Temperature:")
                            Spacer()
                            Text(String(format: "%.1f °C", temp))
                                .foregroundStyle(temp > activityMonitor.overheatingTemperatureThresholdCelsius ? .orange : .secondary)
                        }
                    }

                    if let load = activityMonitor.lastCPULoadPercentage {
                        HStack {
                            Text("CPU Total Load:")
                            Spacer()
                            Text(String(format: "%.1f%%", load))
                                .foregroundStyle(load > activityMonitor.overheatingCPULoadThresholdPercent ? .orange : .secondary)
                        }
                    }

                    Button("Sample Sensors Now") {
                        activityMonitor.performSampleTick()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
