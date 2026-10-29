import SwiftUI

/// Triangle shape used for Bitz's pointed cybernetic cat ears.
public struct CyberEarShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Floating ambient particle overlays for Bitz's states (neon sparks, binary focus bits, sleepy ZZZs, steam puffs).
public struct AmbientParticlesOverlay: View {
    public let state: BitzState
    public let color: Color
    public let time: TimeInterval

    public init(state: BitzState, color: Color, time: TimeInterval) {
        self.state = state
        self.color = color
        self.time = time
    }

    public var body: some View {
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

/// Standalone reusable view representing the core Bitz cybernetic cat figure
/// with its signature pointed cyber ears, wrap-around LED visor, body, paws, and glowing tail.
public struct BitzCharacterView: View {
    public let state: BitzState
    public let time: TimeInterval
    public let isBlinking: Bool
    public let isPetReactionActive: Bool
    public let isLoafPosture: Bool
    public let showParticles: Bool
    public let customVisorColor: Color?

    public init(
        state: BitzState = .balanced,
        time: TimeInterval = 0,
        isBlinking: Bool = false,
        isPetReactionActive: Bool = false,
        isLoafPosture: Bool? = nil,
        showParticles: Bool = true,
        customVisorColor: Color? = nil
    ) {
        self.state = state
        self.time = time
        self.isBlinking = isBlinking
        self.isPetReactionActive = isPetReactionActive
        self.isLoafPosture = isLoafPosture ?? (state == .burnout || state == .charging)
        self.showParticles = showParticles
        self.customVisorColor = customVisorColor
    }

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

    public var visorColor: Color {
        if let custom = customVisorColor {
            return custom
        }
        let rgb = Self.visorRGB(for: state)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    public var animationSpeedMultiplier: Double {
        switch state {
        case .superCharged: return 2.0
        case .balanced: return 1.0
        case .dopamineSad: return 0.35
        case .overworked: return 0.4
        case .burnout: return 0.0
        case .charging: return 0.6
        case .overheating: return 2.5
        }
    }

    public var body: some View {
        let breathOffset = sin(time * 2.8 * animationSpeedMultiplier) * (state == .burnout ? 0.0 : 4.5)
        let glitchOffsetX = state == .overheating ? sin(time * 45.0) * 3.0 : 0.0
        let earTilt = (state == .overworked || state == .dopamineSad) ? 14.0 : 0.0

        ZStack(alignment: .bottom) {
            // Ambient particles behind mascot
            if showParticles {
                AmbientParticlesOverlay(state: state, color: visorColor, time: time)
                    .zIndex(0)
            }

            // Glowing cybernetic tail on the right
            Capsule()
                .fill(Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 29.0 / 255.0))
                .frame(width: 48, height: 14)
                .overlay(
                    Capsule()
                        .stroke(visorColor.opacity(0.85), lineWidth: 2)
                )
                .rotationEffect(.degrees(isLoafPosture ? 0 : -22 + sin(time * 3.2 * animationSpeedMultiplier) * 10))
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
                        .fill(visorColor.opacity(state == .burnout ? 0.3 : 0.9))
                        .frame(width: 12, height: 12)
                        .shadow(color: visorColor, radius: 6)
                        .offset(y: 6)
                )

            // Front Paws (with subtle sway/trot motion when standing)
            if !isLoafPosture {
                let pawSway = sin(time * 3.0 * animationSpeedMultiplier) * 2.0
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
        .frame(width: 180, height: 140)
    }

    @ViewBuilder
    private func visorContent(isBlinking: Bool) -> some View {
        if isPetReactionActive {
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
        } else if state == .charging {
            Text("⚡ Z Z")
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .foregroundStyle(visorColor)
                .shadow(color: visorColor, radius: 6)
        } else if state == .burnout {
            Text("X  X")
                .font(.system(size: 19, weight: .heavy, design: .monospaced))
                .foregroundStyle(visorColor.opacity(0.85))
        } else if state == .dopamineSad {
            Text("T  T")
                .font(.system(size: 19, weight: .heavy, design: .monospaced))
                .foregroundStyle(visorColor)
                .shadow(color: visorColor, radius: 6)
        } else if state == .overheating {
            Text(">  <")
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundStyle(visorColor)
                .shadow(color: visorColor, radius: 6)
        } else if state == .superCharged {
            Text("^  ^")
                .font(.system(size: 21, weight: .heavy, design: .monospaced))
                .foregroundStyle(visorColor)
                .shadow(color: visorColor, radius: 8)
        } else if state == .overworked {
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

/// Self-animating version of `BitzCharacterView` driven by an internal 30 fps timeline.
public struct AnimatedBitzCharacterView: View {
    public let state: BitzState
    public let isLoafPosture: Bool?
    public let showParticles: Bool
    public let customVisorColor: Color?

    public init(
        state: BitzState = .balanced,
        isLoafPosture: Bool? = nil,
        showParticles: Bool = true,
        customVisorColor: Color? = nil
    ) {
        self.state = state
        self.isLoafPosture = isLoafPosture
        self.showParticles = showParticles
        self.customVisorColor = customVisorColor
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let isLoaf = isLoafPosture ?? (state == .burnout || state == .charging)
            let blinkRemainder = t.truncatingRemainder(dividingBy: 4.2)
            let isBlinking = blinkRemainder < 0.16 && !isLoaf && state != .overheating

            BitzCharacterView(
                state: state,
                time: t,
                isBlinking: isBlinking,
                isPetReactionActive: false,
                isLoafPosture: isLoaf,
                showParticles: showParticles,
                customVisorColor: customVisorColor
            )
        }
    }
}
