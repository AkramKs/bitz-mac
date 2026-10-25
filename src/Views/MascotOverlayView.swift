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

/// SwiftUI view hosted inside `MascotOverlayPanel`, rendering the `250x250` transparent
/// cyberpunk mascot canvas, reactive LED visor glow, standby `"ZZZ"` badge, and
/// `"SYSTEM HOT! > <"` thermal warning speech bubble (`FR-001`, `FR-003`, `FR-004`).
public struct MascotOverlayView: View {
    @ObservedObject public var engine: WellnessPointEngine

    public init(engine: WellnessPointEngine) {
        self.engine = engine
    }

    /// Returns the hex color values (`red`, `green`, `blue`) matching the current `BitzState` visor color.
    public static func visorRGB(for state: BitzState) -> (red: Double, green: Double, blue: Double) {
        switch state {
        case .balanced, .burnout:
            // Electric Cyan (#00F0FF)
            return (0.0, 240.0 / 255.0, 1.0)
        case .superCharged:
            // Neon Magenta (#FF007F)
            return (1.0, 0.0, 127.0 / 255.0)
        case .overworked:
            // Warning Amber (#FFB000)
            return (1.0, 176.0 / 255.0, 0.0)
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
        case .overworked:
            return 0.4
        case .burnout:
            return 0.0
        case .overheating:
            return 2.5
        }
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let breathOffset = sin(t * 2.8 * animationSpeedMultiplier) * (engine.currentState == .burnout ? 0.0 : 4.5)
            let glitchOffsetX = engine.currentState == .overheating ? sin(t * 45.0) * 3.0 : 0.0
            let earTilt = engine.currentState == .overworked ? 12.0 : 0.0

            VStack(spacing: 6) {
                Spacer(minLength: 0)

                if let speechText = engine.activeSpeechBubbleText {
                    Text(speechText)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.85, green: 0.08, blue: 0.12).opacity(0.95))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(visorColor, lineWidth: 1.5)
                        )
                        .shadow(color: visorColor.opacity(0.7), radius: 6)
                        .offset(y: -52)
                        .zIndex(2)
                }

                ZStack(alignment: .bottom) {
                    // Glowing cybernetic tail on the right
                    Capsule()
                        .fill(Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 29.0 / 255.0))
                        .frame(width: 48, height: 14)
                        .overlay(
                            Capsule()
                                .stroke(visorColor.opacity(0.85), lineWidth: 2)
                        )
                        .rotationEffect(.degrees(engine.currentState == .burnout ? 0 : -22 + sin(t * 3.2 * animationSpeedMultiplier) * 10))
                        .offset(x: 64, y: -14)

                    // Compact cyber-cat body / loaf base
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(red: 20.0 / 255.0, green: 20.0 / 255.0, blue: 24.0 / 255.0))
                        .frame(width: engine.currentState == .burnout ? 136 : 108, height: engine.currentState == .burnout ? 54 : 68)
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
                                    visorDisplayContent
                                )
                        }
                        .zIndex(1)
                    }
                    .offset(y: engine.currentState == .burnout ? -22 : -44)
                }
                .offset(x: glitchOffsetX, y: breathOffset)

                // Live Cyberpunk Hardware Telemetry Pill (shows real CPU °C, CPU %, and Wellness PTS)
                if let tempC = engine.latestTemperatureCelsius {
                    let cpuString = engine.latestCPULoadPercentage.map { String(format: " • %.0f%% CPU", $0) } ?? ""
                    Text(String(format: "%.1f°C%@ • %.0f PTS", tempC, cpuString, engine.currentPoints))
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
                } else {
                    Spacer().frame(height: 10)
                }
            }
        }
        .frame(width: 250, height: 250)
        .background(Color.clear)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var visorDisplayContent: some View {
        if engine.isPetReactionActive {
            Text("<3  <3")
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(red: 1.0, green: 0.0, blue: 127.0 / 255.0))
                .shadow(color: Color(red: 1.0, green: 0.0, blue: 127.0 / 255.0), radius: 6)
        } else if engine.currentState == .burnout {
            Text("Z Z Z")
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .foregroundStyle(visorColor.opacity(0.75))
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
