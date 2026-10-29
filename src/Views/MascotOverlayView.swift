import SwiftUI

/// SwiftUI view hosted inside `MascotOverlayPanel`, rendering the transparent
/// cyberpunk mascot canvas, reactive LED visor glow, standby `"ZZZ"` badge, and
/// `"SYSTEM HOT! > <"` thermal warning speech bubble (`FR-001`, `FR-003`, `FR-004`).
public struct MascotOverlayView: View {
    @ObservedObject public var engine: WellnessPointEngine
    @ObservedObject public var scaleStore: AvatarScaleStore
    @ObservedObject public var opacityStore: AvatarOpacityStore
    @ObservedObject public var positionStore: AvatarPositionStore
    @ObservedObject public var agentMonitor: AgentMonitorService
    @ObservedObject public var updateStore: AppUpdateStore
    @ObservedObject public var telemetryDashboard: TelemetryDashboardService
    @ObservedObject public var telemetrySettings: TelemetrySettingsStore

    public var onDragChanged: ((NSPoint, NSScreen?) -> Void)?
    public var onDragEnded: ((NSPoint, NSScreen?) -> Void)?
    public var onGetOrigin: (() -> NSPoint?)?
    public var onGetSize: (() -> NSSize)?

    @State private var dragInitialOrigin: NSPoint? = nil
    @State private var isHovering: Bool = false

    public init(
        engine: WellnessPointEngine,
        scaleStore: AvatarScaleStore = AvatarScaleStore(),
        opacityStore: AvatarOpacityStore = AvatarOpacityStore(),
        positionStore: AvatarPositionStore = AvatarPositionStore(),
        agentMonitor: AgentMonitorService = AgentMonitorService(),
        updateStore: AppUpdateStore = AppUpdateStore(),
        telemetryDashboard: TelemetryDashboardService = TelemetryDashboardService(),
        telemetrySettings: TelemetrySettingsStore = TelemetrySettingsStore(),
        onDragChanged: ((NSPoint, NSScreen?) -> Void)? = nil,
        onDragEnded: ((NSPoint, NSScreen?) -> Void)? = nil,
        onGetOrigin: (() -> NSPoint?)? = nil,
        onGetSize: (() -> NSSize)? = nil
    ) {
        self.engine = engine
        self.scaleStore = scaleStore
        self.opacityStore = opacityStore
        self.positionStore = positionStore
        self.agentMonitor = agentMonitor
        self.updateStore = updateStore
        self.telemetryDashboard = telemetryDashboard
        self.telemetrySettings = telemetrySettings
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onGetOrigin = onGetOrigin
        self.onGetSize = onGetSize
    }

    /// Returns the RGB color values (`red`, `green`, `blue`) matching the current `BitzState` visor color.
    public static func visorRGB(for state: BitzState) -> (red: Double, green: Double, blue: Double) {
        switch state {
        case .balanced:
            // Electric Cyan (#00F0FF)
            return (0.0, 240.0 / 255.0, 1.0)
        case .superCharged:
            // Neon Magenta (#FF007F)
            return (1.0, 0.0, 127.0 / 255.0)
        case .dopamineSad:
            // Dopamine Overload Violet (#9D4EDD)
            return (157.0 / 255.0, 78.0 / 255.0, 221.0 / 255.0)
        case .overworked, .burnout:
            // Warning Amber (#FFB000)
            return (1.0, 176.0 / 255.0, 0.0)
        case .charging:
            // Cyber Emerald Green (#00FF88)
            return (0.0, 1.0, 136.0 / 255.0)
        case .overheating:
            // Critical Red (#FF1E1E)
            return (1.0, 30.0 / 255.0, 30.0 / 255.0)
        }
    }

    private var visorColor: Color {
        let rgb = Self.visorRGB(for: engine.currentState)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    private var animationSpeedMultiplier: Double {
        switch engine.currentState {
        case .superCharged:
            return 2.0
        case .balanced:
            return 1.0
        case .dopamineSad:
            return 0.35
        case .overworked:
            return 0.4
        case .burnout:
            return 0.0
        case .charging:
            return 0.6
        case .overheating:
            return 2.5
        }
    }

    private var isLoafPosture: Bool {
        engine.currentState == .burnout || engine.currentState == .charging
    }

    private func agentPopupColor(for kind: AgentEventKind) -> Color {
        switch kind {
        case .needsApproval:
            return Color.yellow
        case .done:
            return Color.green
        case .started, .working:
            return Color.cyan
        }
    }

    private func agentPopupBackground(for kind: AgentEventKind) -> Color {
        switch kind {
        case .needsApproval:
            return Color(red: 0.85, green: 0.45, blue: 0.05).opacity(0.96)
        case .done:
            return Color(red: 0.05, green: 0.65, blue: 0.35).opacity(0.96)
        case .started, .working:
            return Color(red: 0.12, green: 0.45, blue: 0.85).opacity(0.96)
        }
    }

    private func agentBubbleView(for popup: AgentPopupState) -> some View {
        let strokeColor = agentPopupColor(for: popup.kind)
        let bgColor = agentPopupBackground(for: popup.kind)
        return Text(popup.text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: 236)
            .background(RoundedRectangle(cornerRadius: 8).fill(bgColor))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(strokeColor, lineWidth: 1.5))
            .shadow(color: strokeColor.opacity(0.7), radius: 6)
            .offset(y: isLoafPosture ? -30 : -50)
            .zIndex(3)
    }

    private func updateBubbleView(for release: GitHubReleaseInfo) -> some View {
        let accentColor = Color(red: 0.0, green: 0.94, blue: 1.0)
        let bgColor = Color(red: 0.06, green: 0.08, blue: 0.12).opacity(0.96)
        return VStack(spacing: 5) {
            Text("UPDATE READY: v\(release.semanticVersion.description) 🚀")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Button(action: { updateStore.openDownloadPage() }) {
                    Text("DOWNLOAD")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(accentColor))
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(.plain)

                Button(action: { updateStore.dismissAlert() }) {
                    Text("LATER")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().stroke(Color.gray.opacity(0.6), lineWidth: 1))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: 236)
        .background(RoundedRectangle(cornerRadius: 8).fill(bgColor))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accentColor, lineWidth: 1.5))
        .shadow(color: accentColor.opacity(0.6), radius: 6)
        .offset(y: isLoafPosture ? -30 : -50)
        .zIndex(3)
    }

    public var body: some View {
        // 30 fps is plenty for breathing/blink; the uncapped display rate cost ~25-30% of a core at idle (#10)
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let _ = telemetryDashboard.fpsTracker.recordFrame(timestamp: t)

            // Periodic natural eye-blink (every ~4.2s for ~0.15s)
            let blinkRemainder = t.truncatingRemainder(dividingBy: 4.2)
            let isBlinking = blinkRemainder < 0.16 && !isLoafPosture && engine.currentState != .overheating && !engine.isPetReactionActive

            VStack(spacing: 6) {
                Spacer(minLength: 0)

                // Speech Bubble Notification (always 100% solid contrast for legibility)
                // Priority: Agent Monitor active popup takes precedence over wellness text (T016)
                if let agentPopup = agentMonitor.activePopup {
                    agentBubbleView(for: agentPopup)
                } else if updateStore.isSpeechBubbleAlertActive, let release = updateStore.latestRelease {
                    updateBubbleView(for: release)
                } else if let speechText = engine.activeSpeechBubbleText {
                    Text(speechText)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .frame(maxWidth: 236)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    engine.currentState == .overheating
                                        ? Color(red: 0.75, green: 0.06, blue: 0.10).opacity(0.95)
                                        : Color(red: 0.08, green: 0.09, blue: 0.13).opacity(0.94)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(visorColor, lineWidth: 1.5)
                        )
                        .shadow(color: visorColor.opacity(0.7), radius: 6)
                        .offset(y: isLoafPosture ? -30 : -50)
                        .zIndex(3)
                } else if telemetrySettings.displayInSpeechBubbleCycle, let carouselText = telemetryDashboard.currentCarouselMessage {
                    Text(carouselText)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .frame(maxWidth: 236)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.08, green: 0.09, blue: 0.13).opacity(0.94))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(visorColor, lineWidth: 1.5)
                        )
                        .shadow(color: visorColor.opacity(0.7), radius: 6)
                        .offset(y: isLoafPosture ? -30 : -50)
                        .zIndex(3)
                }

                // Mascot Composition with user-selected see-through opacity
                BitzCharacterView(
                    state: engine.currentState,
                    time: t,
                    isBlinking: isBlinking,
                    isPetReactionActive: engine.isPetReactionActive,
                    isLoafPosture: isLoafPosture,
                    showParticles: true,
                    customVisorColor: visorColor
                )
                .opacity(opacityStore.opacityFactor)

                // Live Cyberpunk Hardware Telemetry & Diagnostics HUD
                if telemetrySettings.displayInMascotCyberHUD {
                    let hudText = telemetryDashboard.snapshot.hudSummary(
                        enabledMetrics: telemetrySettings.enabledMetrics,
                        focusPoints: engine.currentPoints
                    )
                    let hasWarning = telemetryDashboard.snapshot.hasActiveWarning
                    let hudBorderColor = hasWarning ? Color.orange : visorColor

                    Text(hudText)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(hudBorderColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.92))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(hudBorderColor.opacity(hasWarning ? 0.95 : 0.65), lineWidth: 1.2)
                        )
                        .shadow(color: hudBorderColor.opacity(0.35), radius: 5)
                        .padding(.bottom, 4)
                        .opacity(max(0.6, opacityStore.opacityFactor))
                } else {
                    Spacer().frame(height: 10)
                }
            }
        }
        .frame(width: 250, height: 250)
        .overlay {
            if positionStore.isInteractivityEnabled {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            visorColor.opacity(positionStore.isDragging ? 0.95 : 0.65),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                        )
                        .shadow(color: visorColor.opacity(0.4), radius: 6)

                    HStack(spacing: 5) {
                        Image(systemName: positionStore.isDragging ? "arrow.up.and.down.and.arrow.left.and.right" : "lock.open.fill")
                            .font(.system(size: 8))
                        Text(positionStore.isDragging ? "DRAGGING" : (positionStore.isPositionUnlocked ? "DRAG • ⎋ ESC / RIGHT-CLICK TO LOCK" : "⌥ HOLD TO DRAG"))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                        if positionStore.isPositionUnlocked {
                            Button(action: { positionStore.lockPosition() }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 7))
                                    Text("LOCK")
                                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(visorColor))
                                .foregroundStyle(Color.black)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .foregroundStyle(visorColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(red: 0.08, green: 0.09, blue: 0.13).opacity(0.92)))
                    .overlay(Capsule().stroke(visorColor.opacity(0.7), lineWidth: 1))
                    .shadow(color: visorColor.opacity(0.4), radius: 4)
                    .offset(y: -14)
                }
                .allowsHitTesting(true)
            }
        }
        .scaleEffect(scaleStore.scaleFactor)
        .frame(
            width: MascotOverlayPanel.defaultPanelSize.width * scaleStore.scaleFactor,
            height: MascotOverlayPanel.defaultPanelSize.height * scaleStore.scaleFactor
        )
        .background(Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if positionStore.isInteractivityEnabled {
                if hovering {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { gesture in
                    guard positionStore.isInteractivityEnabled else { return }
                    if !positionStore.isDragging {
                        positionStore.isDragging = true
                        NSCursor.closedHand.push()
                        dragInitialOrigin = onGetOrigin?() ?? .zero
                    }
                    guard let startOrigin = dragInitialOrigin else { return }
                    let candidateOrigin = NSPoint(
                        x: startOrigin.x + gesture.translation.width,
                        y: startOrigin.y - gesture.translation.height
                    )
                    let mouseLoc = NSEvent.mouseLocation
                    let targetScreen = NSScreen.screens.first(where: { NSPointInRect(mouseLoc, $0.frame) })
                        ?? NSScreen.main
                    let targetVisibleFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
                    let panelSize = onGetSize?() ?? MascotOverlayPanel.defaultPanelSize
                    let clamped = MascotOverlayPanel.clampOriginToVisibleFrame(
                        candidateOrigin,
                        panelSize: panelSize,
                        visibleFrame: targetVisibleFrame
                    )
                    onDragChanged?(clamped, targetScreen)
                }
                .onEnded { gesture in
                    guard positionStore.isInteractivityEnabled else { return }
                    if positionStore.isDragging {
                        NSCursor.pop()
                        positionStore.isDragging = false
                    }
                    let startOrigin = dragInitialOrigin ?? onGetOrigin?() ?? .zero
                    dragInitialOrigin = nil

                    let candidateOrigin = NSPoint(
                        x: startOrigin.x + gesture.translation.width,
                        y: startOrigin.y - gesture.translation.height
                    )
                    let mouseLoc = NSEvent.mouseLocation
                    let targetScreen = NSScreen.screens.first(where: { NSPointInRect(mouseLoc, $0.frame) })
                        ?? NSScreen.main
                    let targetVisibleFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
                    let panelSize = onGetSize?() ?? MascotOverlayPanel.defaultPanelSize
                    let finalClamped = MascotOverlayPanel.clampOriginToVisibleFrame(
                        candidateOrigin,
                        panelSize: panelSize,
                        visibleFrame: targetVisibleFrame
                    )

                    positionStore.setCustomPosition(finalClamped)
                    onDragEnded?(finalClamped, targetScreen)
                }
        )
        .onTapGesture(count: 2) {
            if positionStore.isPositionUnlocked {
                positionStore.lockPosition()
            }
        }
        .contextMenu {
            if positionStore.isPositionUnlocked {
                Button {
                    positionStore.lockPosition()
                } label: {
                    Label("Lock Position", systemImage: "lock.fill")
                }
                Button {
                    positionStore.resetToDefaultCorner()
                } label: {
                    Label("Reset to Default Corner", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .allowsHitTesting(positionStore.isInteractivityEnabled || updateStore.isSpeechBubbleAlertActive)
    }
}
