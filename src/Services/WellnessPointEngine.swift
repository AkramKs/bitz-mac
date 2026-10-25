import Combine
import Foundation

// MARK: - Domain State Enumeration

/// Represents the discrete behavioral and emotional states of Bitz the Cyber Cat.
public enum BitzState: String, Sendable, Equatable, CaseIterable {
    case superCharged
    case balanced
    case dopamineSad
    case overworked
    case burnout
    case charging
    case overheating
}

// MARK: - Rive State Machine Constants

/// Canonical input identifiers for the Rive `BitzStateMachine`.
public enum BitzRiveInputName {
    public static let stateMachineName = "BitzStateMachine"
    public static let speedMultiplier = "speedMultiplier"
    public static let visorColor = "visorColor"
    public static let isStandby = "isStandby"
    public static let isGlitching = "isGlitching"
    public static let triggerPet = "triggerPet"

    public static let allInputNames: Set<String> = [
        speedMultiplier,
        visorColor,
        isStandby,
        isGlitching,
        triggerPet
    ]
}

/// Canonical float values for the Rive `visorColor` input.
public enum BitzVisorColor {
    /// Balanced state (`#00F0FF` Electric Cyan).
    public static let cyan: Float = 0.0
    /// Super Charged state (`#FF007F` Neon Magenta).
    public static let magenta: Float = 1.0
    /// Overworked state (`#FFB000` Warning Amber).
    public static let amber: Float = 2.0
    /// Overheating state (`#FF1E1E` Critical Red).
    public static let red: Float = 3.0
    /// Dopamine Sad / Distracted state (`#8A2BE2` Electric Violet).
    public static let purple: Float = 4.0
    /// Charging / Idle Break state (`#00FF88` Cyber Emerald Green).
    public static let green: Float = 5.0
}

// MARK: - Rive State Machine Adapter Seam

/// Value log entry capturing an exact Rive state machine mutation command.
public enum BitzRiveCommand: Sendable, Equatable {
    case setFloat(String, Float)
    case setBool(String, Bool)
    case fireTrigger(String)
}

/// Protocol seam abstracting Rive `RiveViewModel` input mutations for deterministic testing.
@MainActor
public protocol BitzRiveControllable: AnyObject {
    func setInput(_ name: String, value: Float)
    func setInput(_ name: String, value: Bool)
    func triggerInput(_ name: String)
}

/// Deterministic test spy recording all Rive state machine input updates and trigger invocations.
@MainActor
public final class SpyRiveController: BitzRiveControllable {
    public private(set) var commands: [BitzRiveCommand] = []
    public private(set) var floatInputs: [String: Float] = [:]
    public private(set) var boolInputs: [String: Bool] = [:]
    public private(set) var triggerCounts: [String: Int] = [:]

    public init() {}

    public func setInput(_ name: String, value: Float) {
        commands.append(.setFloat(name, value))
        floatInputs[name] = value
    }

    public func setInput(_ name: String, value: Bool) {
        commands.append(.setBool(name, value))
        boolInputs[name] = value
    }

    public func triggerInput(_ name: String) {
        commands.append(.fireTrigger(name))
        triggerCounts[name, default: 0] += 1
    }

    public func resetRecordedCommands() {
        commands.removeAll()
    }
}

/// Production Rive state machine controller maintaining current Rive `BitzStateMachine` state
/// and forwarding updates to any bound Rive runtime view model handler.
@MainActor
public final class ProductionRiveController: BitzRiveControllable {
    public let fileName: String
    public let stateMachineName: String

    public private(set) var floatInputs: [String: Float] = [:]
    public private(set) var boolInputs: [String: Bool] = [:]
    public private(set) var lastTriggeredInput: String?
    public private(set) var totalTriggerCount: Int = 0

    public var onCommandDispatched: ((BitzRiveCommand) -> Void)?

    public init(
        fileName: String = "bitz_cyber_cat",
        stateMachineName: String = BitzRiveInputName.stateMachineName,
        onCommandDispatched: ((BitzRiveCommand) -> Void)? = nil
    ) {
        self.fileName = fileName
        self.stateMachineName = stateMachineName
        self.onCommandDispatched = onCommandDispatched
    }

    public func setInput(_ name: String, value: Float) {
        floatInputs[name] = value
        onCommandDispatched?(.setFloat(name, value))
    }

    public func setInput(_ name: String, value: Bool) {
        boolInputs[name] = value
        onCommandDispatched?(.setBool(name, value))
    }

    public func triggerInput(_ name: String) {
        lastTriggeredInput = name
        totalTriggerCount += 1
        onCommandDispatched?(.fireTrigger(name))
    }
}

// MARK: - WellnessPointEngine

/// Core reactive domain engine managing Bitz's wellness score (`0.0...100.0`),
/// continuous work duration (`continuousWorkMinutes`), behavioral `BitzState`,
/// contextual speech bubbles, and Rive state machine synchronization.
@MainActor
public final class WellnessPointEngine: ObservableObject {
    public static let thermalWarningText = "🔥 SYSTEM HOT! CLOSE HEAVY APPS TO COOL DOWN"
    public static let dopamineSadText = "DOPAMINE OVERLOAD — BACK TO FOCUS?"
    public static let overworkedWarningText = "WORKING NON-STOP — TAKE A QUICK BREAK ☕"
    public static let burnoutWarningText = "BURNOUT! STEP AWAY FOR 5 MIN TO RECHARGE 💤"
    public static let chargingStatusText = "CHARGING ENERGY... ⚡"

    public static let productiveTickDelta: Double = 0.5
    public static let unproductiveTickDelta: Double = -1.5
    public static let chargingTickDelta: Double = 0.5
    public static let offlineBreakMinThresholdMinutes: Double = 2.0
    public static let offlineBreakPointsPerMinute: Double = 5.0

    /// Continuous work duration thresholds (in minutes without a break) that trigger `.overworked` and `.burnout`.
    public static let overworkedWorkMinutesThreshold: Double = 45.0
    public static let burnoutWorkMinutesThreshold: Double = 90.0

    @Published public private(set) var currentPoints: Double = 50.0
    @Published public private(set) var continuousWorkMinutes: Double = 0.0
    @Published public private(set) var currentState: BitzState = .balanced
    @Published public private(set) var activeSpeechBubbleText: String? = nil
    @Published public private(set) var isPetReactionActive: Bool = false
    @Published public var latestTemperatureCelsius: Double? = nil
    @Published public var latestCPULoadPercentage: Double? = nil

    public let maxPoints: Double = 100.0
    public let minPoints: Double = 0.0

    public var riveController: BitzRiveControllable?
    private var isOverheatingOverride: Bool = false
    private var customOverheatingMessage: String? = nil
    private var isChargingOverride: Bool = false

    public init(
        initialPoints: Double = 50.0,
        initialContinuousWorkMinutes: Double = 0.0,
        riveController: BitzRiveControllable? = nil
    ) {
        self.riveController = riveController
        self.currentPoints = min(max(initialPoints, minPoints), maxPoints)
        self.continuousWorkMinutes = max(0.0, initialContinuousWorkMinutes)
        evaluateState()
    }

    /// Evaluates a single work tick:
    /// - Productive app (`+0.5 PTS`, increments `continuousWorkMinutes` toward `.overworked`/`.burnout` if no break is taken).
    /// - Unproductive/entertainment app (`-1.5 PTS`, drains toward `.dopamineSad` when `< 40 PTS`).
    public func evaluateWorkTick(isProductiveApp: Bool, tickDurationMinutes: Double = 5.0 / 60.0) {
        if isChargingOverride {
            isChargingOverride = false
        }
        let delta = isProductiveApp ? Self.productiveTickDelta : Self.unproductiveTickDelta
        currentPoints = min(max(currentPoints + delta, minPoints), maxPoints)

        if isProductiveApp {
            continuousWorkMinutes += max(0.0, tickDurationMinutes)
        }

        if !isOverheatingOverride {
            evaluateState()
        }
    }

    /// Activates or deactivates `.charging` mode when the user steps away from the keyboard/mouse.
    /// While charging, each sample tick restores `+0.5 PTS` and reduces continuous work fatigue.
    public func setChargingState(_ isCharging: Bool) {
        isChargingOverride = isCharging
        if isCharging {
            currentPoints = min(max(currentPoints + Self.chargingTickDelta, minPoints), maxPoints)
            continuousWorkMinutes = max(0.0, continuousWorkMinutes - 5.0)
        }
        if !isOverheatingOverride {
            evaluateState()
        }
    }

    /// Restores `+5.0` points per minute when returning from an offline break (`> 2.0` minutes)
    /// and resets continuous work fatigue (`continuousWorkMinutes = 0`).
    public func applyOfflineBreak(minutes: Double) {
        isChargingOverride = false
        guard minutes > Self.offlineBreakMinThresholdMinutes else {
            if !isOverheatingOverride {
                evaluateState()
            }
            return
        }
        let restoredPoints = minutes * Self.offlineBreakPointsPerMinute
        currentPoints = min(max(currentPoints + restoredPoints, minPoints), maxPoints)
        continuousWorkMinutes = 0.0
        if !isOverheatingOverride {
            evaluateState()
        }
    }

    /// Triggers or clears the `.overheating` state override with an actionable cool-down message above Bitz.
    public func triggerThermalWarning(isOverheating: Bool, actionMessage: String? = nil) {
        if isOverheating {
            isOverheatingOverride = true
            customOverheatingMessage = actionMessage ?? Self.thermalWarningText
            currentState = .overheating
            activeSpeechBubbleText = customOverheatingMessage
            syncWithRive()
        } else {
            isOverheatingOverride = false
            customOverheatingMessage = nil
            evaluateState()
        }
    }

    /// Fires the Rive `"triggerPet"` interaction input and activates a brief `<3` visor reaction.
    public func triggerPetInteraction() {
        riveController?.triggerInput(BitzRiveInputName.triggerPet)
        isPetReactionActive = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.isPetReactionActive = false
        }
    }

    /// Sets `currentPoints` and optional `continuousWorkMinutes` directly, clears thermal/charging overrides,
    /// and re-evaluates `currentState` and Rive inputs.
    public func setPoints(_ points: Double, continuousWorkMinutes: Double = 0.0) {
        isOverheatingOverride = false
        customOverheatingMessage = nil
        isChargingOverride = false
        self.currentPoints = min(max(points, minPoints), maxPoints)
        self.continuousWorkMinutes = max(0.0, continuousWorkMinutes)
        evaluateState()
    }

    /// Evaluates `currentState` and contextual `activeSpeechBubbleText` from overrides,
    /// continuous work duration (`overworked` / `burnout`), and focus points (`superCharged` / `balanced` / `dopamineSad`).
    public func evaluateState() {
        if isOverheatingOverride {
            currentState = .overheating
            activeSpeechBubbleText = customOverheatingMessage ?? Self.thermalWarningText
            syncWithRive()
            return
        }

        if isChargingOverride {
            currentState = .charging
            activeSpeechBubbleText = Self.chargingStatusText
            syncWithRive()
            return
        }

        if continuousWorkMinutes >= Self.burnoutWorkMinutesThreshold {
            currentState = .burnout
            activeSpeechBubbleText = Self.burnoutWarningText
            syncWithRive()
            return
        }

        if continuousWorkMinutes >= Self.overworkedWorkMinutesThreshold {
            currentState = .overworked
            activeSpeechBubbleText = Self.overworkedWarningText
            syncWithRive()
            return
        }

        let newState = Self.state(forPoints: currentPoints)
        currentState = newState
        switch newState {
        case .dopamineSad:
            activeSpeechBubbleText = Self.dopamineSadText
        case .superCharged, .balanced, .overworked, .burnout, .charging, .overheating:
            activeSpeechBubbleText = nil
        }
        syncWithRive()
    }

    /// Pure threshold mapping from `points` (`0.0...100.0`) when not on a continuous-work burnout streak:
    /// - `80.0...100.0`: `.superCharged`
    /// - `40.0..<80.0`: `.balanced`
    /// - `< 40.0`: `.dopamineSad` (too much YouTube / Netflix / distraction)
    public static func state(forPoints points: Double) -> BitzState {
        switch points {
        case 80.0...100.0:
            return .superCharged
        case 40.0..<80.0:
            return .balanced
        default:
            return .dopamineSad
        }
    }

    /// Pushes the current `BitzState` inputs to the bound `BitzRiveControllable`.
    public func syncWithRive() {
        guard let rive = riveController else { return }

        switch currentState {
        case .superCharged:
            rive.setInput(BitzRiveInputName.speedMultiplier, value: Float(2.0))
            rive.setInput(BitzRiveInputName.visorColor, value: BitzVisorColor.magenta)
            rive.setInput(BitzRiveInputName.isGlitching, value: false)
            rive.setInput(BitzRiveInputName.isStandby, value: false)

        case .balanced:
            rive.setInput(BitzRiveInputName.speedMultiplier, value: Float(1.0))
            rive.setInput(BitzRiveInputName.visorColor, value: BitzVisorColor.cyan)
            rive.setInput(BitzRiveInputName.isGlitching, value: false)
            rive.setInput(BitzRiveInputName.isStandby, value: false)

        case .dopamineSad:
            rive.setInput(BitzRiveInputName.speedMultiplier, value: Float(0.35))
            rive.setInput(BitzRiveInputName.visorColor, value: BitzVisorColor.purple)
            rive.setInput(BitzRiveInputName.isGlitching, value: false)
            rive.setInput(BitzRiveInputName.isStandby, value: false)

        case .overworked:
            rive.setInput(BitzRiveInputName.speedMultiplier, value: Float(0.4))
            rive.setInput(BitzRiveInputName.visorColor, value: BitzVisorColor.amber)
            rive.setInput(BitzRiveInputName.isGlitching, value: false)
            rive.setInput(BitzRiveInputName.isStandby, value: false)

        case .burnout:
            rive.setInput(BitzRiveInputName.speedMultiplier, value: Float(0.0))
            rive.setInput(BitzRiveInputName.visorColor, value: BitzVisorColor.amber)
            rive.setInput(BitzRiveInputName.isStandby, value: true)
            rive.setInput(BitzRiveInputName.isGlitching, value: false)

        case .charging:
            rive.setInput(BitzRiveInputName.speedMultiplier, value: Float(0.5))
            rive.setInput(BitzRiveInputName.visorColor, value: BitzVisorColor.green)
            rive.setInput(BitzRiveInputName.isStandby, value: true)
            rive.setInput(BitzRiveInputName.isGlitching, value: false)

        case .overheating:
            rive.setInput(BitzRiveInputName.isGlitching, value: true)
            rive.setInput(BitzRiveInputName.visorColor, value: BitzVisorColor.red)
        }
    }
}
