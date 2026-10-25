import SwiftUI

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

    public var body: some View {
        VStack(spacing: 8) {
            if let speechText = engine.activeSpeechBubbleText {
                Text(speechText)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.85, green: 0.08, blue: 0.12).opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(visorColor, lineWidth: 1.5)
                    )
            }

            ZStack {
                // Matte charcoal cyber-cat chassis (#1A1A1D)
                RoundedRectangle(cornerRadius: 36)
                    .fill(Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 29.0 / 255.0))
                    .frame(width: 140, height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36)
                            .stroke(visorColor.opacity(0.65), lineWidth: 2)
                    )

                // Wrap-around glossy black LED visor with reactive neon display
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .frame(width: 108, height: 44)
                    .overlay(
                        Group {
                            if engine.currentState == .burnout {
                                Text("ZZZ")
                                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(visorColor.opacity(0.75))
                            } else if engine.currentState == .overheating {
                                Text("> <")
                                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(visorColor)
                            } else {
                                HStack(spacing: 22) {
                                    Capsule()
                                        .fill(visorColor)
                                        .frame(width: 18, height: 10)
                                    Capsule()
                                        .fill(visorColor)
                                        .frame(width: 18, height: 10)
                                }
                            }
                        }
                    )
            }
        }
        .frame(width: 250, height: 250)
        .background(Color.clear)
        .allowsHitTesting(false)
    }
}
