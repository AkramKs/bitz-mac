import SwiftUI
import AppKit

/// Settings tab for customizing mascot size, opacity, screen placement, and multi-monitor routing.
public struct GeneralSettingsTabView: View {
    @ObservedObject public var scaleStore: AvatarScaleStore
    @ObservedObject public var opacityStore: AvatarOpacityStore
    @ObservedObject public var positionStore: AvatarPositionStore
    @ObservedObject public var displayStore: DisplayPreferenceStore

    public init(
        scaleStore: AvatarScaleStore,
        opacityStore: AvatarOpacityStore,
        positionStore: AvatarPositionStore,
        displayStore: DisplayPreferenceStore
    ) {
        self.scaleStore = scaleStore
        self.opacityStore = opacityStore
        self.positionStore = positionStore
        self.displayStore = displayStore
    }

    public var body: some View {
        Form {
            // MARK: - Avatar Scale Section
            Section("Avatar Size & Scale") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current Size:")
                        Spacer()
                        Text(scaleStore.formattedSizeSummary)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button("Smaller (-10%)") {
                            scaleStore.stepDown()
                        }
                        .disabled(!scaleStore.canStepDown)

                        Button("Larger (+10%)") {
                            scaleStore.stepUp()
                        }
                        .disabled(!scaleStore.canStepUp)

                        if !scaleStore.isPresetSelected(.defaultSize) {
                            Button("Reset (100%)") {
                                scaleStore.resetToDefault()
                            }
                        }
                    }

                    Picker("Size Presets", selection: Binding(
                        get: { AvatarSizePreset.allCases.first(where: { scaleStore.isPresetSelected($0) }) ?? .defaultSize },
                        set: { scaleStore.selectPreset($0) }
                    )) {
                        ForEach(AvatarSizePreset.allCases, id: \.rawValue) { preset in
                            Text(preset.menuTitle).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // MARK: - Avatar Opacity Section
            Section("Mascot Opacity") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current Opacity:")
                        Spacer()
                        Text(opacityStore.formattedOpacitySummary)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button("More Transparent (-10%)") {
                            opacityStore.stepDown()
                        }
                        .disabled(!opacityStore.canStepDown)

                        Button("More Solid (+10%)") {
                            opacityStore.stepUp()
                        }
                        .disabled(!opacityStore.canStepUp)
                    }

                    Picker("Opacity Presets", selection: Binding(
                        get: { AvatarOpacityPreset.allCases.first(where: { opacityStore.isPresetSelected($0) }) ?? .translucent },
                        set: { opacityStore.selectPreset($0) }
                    )) {
                        ForEach(AvatarOpacityPreset.allCases, id: \.rawValue) { preset in
                            Text(preset.menuTitle).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // MARK: - Positioning & Dragging Section
            Section("Position & Screen Anchoring") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Position:")
                        Spacer()
                        Text(positionStore.formattedPositionSummary)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        if positionStore.isPositionUnlocked {
                            Button("Lock Position [⎋ Esc]") {
                                positionStore.lockPosition()
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Unlock Position (Drag to Move)") {
                                positionStore.unlockPosition()
                            }
                        }

                        if positionStore.isFreeform || positionStore.cornerAnchor != .bottomRight {
                            Button("Reset to Bottom-Right") {
                                positionStore.resetToDefaultCorner()
                            }
                        }
                    }

                    Text("💡 Tip: Hold ⌥ Option anytime to drag Bitz across your display.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Corner Anchor", selection: Binding(
                        get: { positionStore.cornerAnchor },
                        set: { positionStore.selectCorner($0) }
                    )) {
                        ForEach(ScreenCornerAnchor.allCases, id: \.rawValue) { corner in
                            Text(corner.menuTitle).tag(corner)
                        }
                    }
                }
            }

            // MARK: - Displays & Multi-Monitor Section
            Section("Display Routing") {
                Picker("Target Display", selection: Binding(
                    get: { displayStore.targetMode },
                    set: { displayStore.selectMode($0) }
                )) {
                    Text("Primary Screen").tag(DisplayTargetMode.primary)
                    Text("Follow Active Screen").tag(DisplayTargetMode.followActive)
                    Text("All Screens").tag(DisplayTargetMode.allDisplays)
                }

                if !displayStore.connectedScreens.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connected Screens:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(displayStore.connectedScreens) { screen in
                            let isSelected = (displayStore.targetMode == .specific && displayStore.targetDisplayID == screen.id)
                            Button(isSelected ? "✓ \(screen.name)" : screen.name) {
                                displayStore.selectSpecificDisplay(id: screen.id, name: screen.name)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
