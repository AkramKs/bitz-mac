import SwiftUI

/// Triangle shape used for Bitz's pointed cybernetic cat ears.
private struct CyberEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Floating ambient particle overlays for Bitz's states (neon sparks, binary focus bits, sleepy ZZZs, steam puffs).
private struct AmbientParticlesOverlay: View {
    let state: BitzState
    let color: Color
    let time: TimeInterval

    var body: some View {
        ZStack {
            if state == .superCharged {
                // Neon sparks drifting upward
                ForEach(0..<4, id: \.self) { i in
                    let offsetPhase = (time * 1.5 + Double(i) * 0.75).truncatingRemainder(dividingBy: 2.0)
                    let xOffset = Double([-36, 42, -54, 38][i]) + sin(time * 3.0 + Double(i)) * 6.0
                    let yOffset = -20.0 - (offsetPhase * 45.0)
                    let opacity = max(0.0, 1.0 - (offsetPhase / 2.0))
                    Circle()
                        .fill(color)
                        .frame(width: 3.5, height: 3.5)
                        .shadow(color: color, radius: 4)
                        .offset(x: xOffset, y: yOffset)
                        .opacity(opacity)
                }
            } else if state == .balanced {
                // Floating cybernetic binary bits (0 1)
                ForEach(0..<3, id: \.self) { i in
                    let phase = (time * 0.8 + Double(i) * 0.9).truncatingRemainder(dividingBy: 2.5)
                    let xOffset = Double([-42, 50, 20][i]) + sin(time * 1.5 + Double(i)) * 4.0
                    let yOffset = -25.0 - (phase * 30.0)
                    let opacity = max(0.0, 1.0 - (phase / 2.5))
                    Text(i % 2 == 0 ? "1" : "0")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                        .shadow(color: color.opacity(0.8), radius: 3)
                        .offset(x: xOffset, y: yOffset)
                        .opacity(opacity)
                }
            } else if state == .charging || state == .burnout {
                // Drifting sleepy ZZZ particles
                ForEach(0..<3, id: \.self) { i in
                    let phase = (time * 0.6 + Double(i) * 1.0).truncatingRemainder(dividingBy: 3.0)
                    let xOffset = 30.0 + Double(i * 12) + sin(time * 1.2 + Double(i)) * 5.0
                    let yOffset = -35.0 - (phase * 35.0)
                    let opacity = max(0.0, 1.0 - (phase / 3.0))
                    Text(i == 0 ? "z" : (i == 1 ? "Z" : "Zz"))
                        .font(.system(size: CGFloat(8 + i * 2), weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .shadow(color: color.opacity(0.6), radius: 3)
                        .offset(x: xOffset, y: yOffset)
                        .opacity(opacity)
                }
            } else if state == .overheating {
                // Steam puffs rising from ears
                ForEach(0..<4, id: \.self) { i in
                    let phase = (time * 2.2 + Double(i) * 0.6).truncatingRemainder(dividingBy: 1.5)
                    let isLeftEar = i % 2 == 0
                    let xOffset = (isLeftEar ? -34.0 : 34.0) + sin(time * 4.0 + Double(i)) * 5.0
                    let yOffset = -70.0 - (phase * 35.0)
                    let opacity = max(0.0, 0.85 - (phase / 1.5))
                    Circle()
                        .fill(Color(white: 0.85).opacity(0.6))
                        .frame(width: CGFloat(6 + Int(phase * 8)), height: CGFloat(6 + Int(phase * 8)))
                        .offset(x: xOffset, y: yOffset)
                        .opacity(opacity)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// SwiftUI view hosted inside `MascotOverlayPanel`, rendering the transparent
/// cyberpunk mascot canvas, reactive LED visor glow, standby `"ZZZ"` badge, and
/// `"SYSTEM HOT! > <"` thermal warning speech bubble (`FR-001`, `FR-003`, `FR-004`).
public struct MascotOverlayView: View {
    @ObservedObject public var engine: WellnessPointEngine
    @ObservedObject public var scaleStore: AvatarScaleStore
    @ObservedObject public var opacityStore: AvatarOpacityStore
    @ObservedObject public var agentMonitor: AgentMonitorService

    public init(
        engine: WellnessPointEngine,
        scaleStore: AvatarScaleStore = AvatarScaleStore(),
        opacityStore: AvatarOpacityStore = AvatarOpacityStore(),
        agentMonitor: AgentMonitorService = AgentMonitorService()
    ) {
        self.engine = engine
        self.scaleStore = scaleStore
        self.opacityStore = opacityStore
        self.agentMonitor = agentMonitor
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

    public var body: some View {
        // 30 fps is plenty for breathing/blink; the uncapped display rate cost ~25-30% of a core at idle (#10)
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let breathOffset = sin(t * 2.8 * animationSpeedMultiplier) * (engine.currentState == .burnout ? 0.0 : 4.5)
            let glitchOffsetX = engine.currentState == .overheating ? sin(t * 45.0) * 3.0 : 0.0
            let earTilt = (engine.currentState == .overworked || engine.currentState == .dopamineSad) ? 14.0 : 0.0

            // Periodic natural eye-blink (every ~4.2s for ~0.15s)
            let blinkRemainder = t.truncatingRemainder(dividingBy: 4.2)
            let isBlinking = blinkRemainder < 0.16 && !isLoafPosture && engine.currentState != .overheating && !engine.isPetReactionActive

            VStack(spacing: 6) {
                Spacer(minLength: 0)

                // Speech Bubble Notification (always 100% solid contrast for legibility)
                // Priority: Agent Monitor active popup takes precedence over wellness text (T016)
                if let agentPopup = agentMonitor.activePopup {
                    agentBubbleView(for: agentPopup)
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
                }

                // Mascot Composition with user-selected see-through opacity
                ZStack(alignment: .bottom) {
                    // Ambient particles behind mascot
                    AmbientParticlesOverlay(state: engine.currentState, color: visorColor, time: t)
                        .zIndex(0)

                    // Glowing cybernetic tail on the right
                    Capsule()
                        .fill(Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 29.0 / 255.0))
                        .frame(width: 48, height: 14)
                        .overlay(
                            Capsule()
                                .stroke(visorColor.opacity(0.85), lineWidth: 2)
                        )
                        .rotationEffect(.degrees(isLoafPosture ? 0 : -22 + sin(t * 3.2 * animationSpeedMultiplier) * 10))
                        .offset(x: 64, y: -14)

                    // Compact cyber-cat body / loaf base
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(red: 20.0 / 255.0, green: 20.0 / 255.0, blue: 24.0 / 255.0))
                        .frame(width: isLoafPosture ? 136 : 108, height: isLoafPosture ? 54 : 68)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(visorColor.opacity(0.45), lineWidth: 1.5)
                        )
                        .overlay(
                            // Chest neon core emblem
                            Circle()
                                .fill(visorColor.opacity(engine.currentState == .burnout ? 0.3 : 0.9))
                                .frame(width: 12, height: 12)
                                .shadow(color: visorColor, radius: 6)
                                .offset(y: 6)
                        )

                    // Front Paws (with subtle sway/trot motion when standing)
                    if !isLoafPosture {
                        let pawSway = sin(t * 3.0 * animationSpeedMultiplier) * 2.0
                        HStack(spacing: 28) {
                            Capsule()
                                .fill(Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 29.0 / 255.0))
                                .frame(width: 18, height: 10)
                                .overlay(Capsule().stroke(visorColor.opacity(0.65), lineWidth: 1))
                                .offset(y: pawSway)
                            Capsule()
                                .fill(Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 29.0 / 255.0))
                                .frame(width: 18, height: 10)
                                .overlay(Capsule().stroke(visorColor.opacity(0.65), lineWidth: 1))
                                .offset(y: -pawSway)
                        }
                        .offset(y: -4)
                        .zIndex(2)
                    }

                    // Head & Ears Assembly
                    VStack(spacing: -10) {
                        // Pointed Cybernetic Cat Ears
                        HStack(spacing: 48) {
                            ZStack {
                                CyberEarShape()
                                    .fill(Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 29.0 / 255.0))
                                    .frame(width: 36, height: 34)
                                CyberEarShape()
                                    .fill(visorColor.opacity(0.85))
                                    .frame(width: 18, height: 18)
                                    .offset(y: 4)
                            }
                            .rotationEffect(.degrees(-8 - earTilt))

                            ZStack {
                                CyberEarShape()
                                    .fill(Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 29.0 / 255.0))
                                    .frame(width: 36, height: 34)
                                CyberEarShape()
                                    .fill(visorColor.opacity(0.85))
                                    .frame(width: 18, height: 18)
                                    .offset(y: 4)
                            }
                            .rotationEffect(.degrees(8 + earTilt))
                        }
                        .zIndex(0)

                        // Matte charcoal cyber-cat head (#1A1A1D)
                        ZStack {
                            RoundedRectangle(cornerRadius: 34)
                                .fill(Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 29.0 / 255.0))
                                .frame(width: 132, height: 92)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 34)
                                        .stroke(visorColor.opacity(0.75), lineWidth: 2)
                                )
                                .shadow(color: visorColor.opacity(0.35), radius: 8)

                            // Wrap-around glossy black LED visor
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(red: 0.04, green: 0.04, blue: 0.06))
                                .frame(width: 108, height: 46)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(visorColor.opacity(0.5), lineWidth: 1)
                                )
                                .overlay(
                                    visorContent(isBlinking: isBlinking)
                                )
                        }
                        .zIndex(1)
                    }
                    .offset(y: isLoafPosture ? -22 : -44)
                }
                .offset(x: glitchOffsetX, y: breathOffset)
                .opacity(opacityStore.opacityFactor)

                // Live Cyberpunk Hardware Telemetry Pill (shows real CPU °C, CPU %, and Wellness PTS)
                if let tempC = engine.latestTemperatureCelsius {
                    let cpuString = engine.latestCPULoadPercentage.map { String(format: " • %.0f%% CPU", $0) } ?? ""
                    Text(String(format: "%.1f°C%@ • %.1f PTS", tempC, cpuString, engine.currentPoints))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(visorColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.06, green: 0.06, blue: 0.08).opacity(0.88))
                        )
                        .overlay(
                            Capsule()
                                .stroke(visorColor.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: visorColor.opacity(0.4), radius: 4)
                        .padding(.bottom, 4)
                        .opacity(max(0.6, opacityStore.opacityFactor))
                } else {
                    Spacer().frame(height: 10)
                }
            }
        }
        .frame(width: 250, height: 250)
        .scaleEffect(scaleStore.scaleFactor)
        .frame(
            width: MascotOverlayPanel.defaultPanelSize.width * scaleStore.scaleFactor,
            height: MascotOverlayPanel.defaultPanelSize.height * scaleStore.scaleFactor
        )
        .background(Color.clear)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func visorContent(isBlinking: Bool) -> some View {
        if engine.isPetReactionActive {
            Text("<3  <3")
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(red: 1.0, green: 0.0, blue: 127.0 / 255.0))
                .shadow(color: Color(red: 1.0, green: 0.0, blue: 127.0 / 255.0), radius: 6)
        } else if isBlinking {
            // Natural blink slit
            HStack(spacing: 24) {
                Capsule()
                    .fill(visorColor)
                    .frame(width: 18, height: 3)
                Capsule()
                    .fill(visorColor)
                    .frame(width: 18, height: 3)
            }
            .shadow(color: visorColor, radius: 4)
        } else if engine.currentState == .charging {
            Text("⚡ Z Z")
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .foregroundStyle(visorColor)
                .shadow(color: visorColor, radius: 6)
        } else if engine.currentState == .burnout {
            Text("X  X")
                .font(.system(size: 19, weight: .heavy, design: .monospaced))
                .foregroundStyle(visorColor.opacity(0.85))
        } else if engine.currentState == .dopamineSad {
            Text("T  T")
                .font(.system(size: 19, weight: .heavy, design: .monospaced))
                .foregroundStyle(visorColor)
                .shadow(color: visorColor, radius: 6)
        } else if engine.currentState == .overheating {
            Text(">  <")
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundStyle(visorColor)
                .shadow(color: visorColor, radius: 6)
        } else if engine.currentState == .superCharged {
            Text("^  ^")
                .font(.system(size: 21, weight: .heavy, design: .monospaced))
                .foregroundStyle(visorColor)
                .shadow(color: visorColor, radius: 8)
        } else if engine.currentState == .overworked {
            HStack(spacing: 24) {
                Rectangle()
                    .fill(visorColor)
                    .frame(width: 20, height: 5)
                Rectangle()
                    .fill(visorColor)
                    .frame(width: 20, height: 5)
            }
            .shadow(color: visorColor, radius: 4)
        } else {
            HStack(spacing: 24) {
                Capsule()
                    .fill(visorColor)
                    .frame(width: 18, height: 11)
                Capsule()
                    .fill(visorColor)
                    .frame(width: 18, height: 11)
            }
            .shadow(color: visorColor, radius: 6)
        }
    }
}
