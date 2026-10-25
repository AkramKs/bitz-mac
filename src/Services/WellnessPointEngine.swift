import Combine
import Foundation

// MARK: - Domain State Enumeration

/// Represents the 5 discrete behavioral states of Bitz the Cyber Cat.
public enum BitzState: String, Sendable, Equatable, CaseIterable {
    case superCharged
    case balanced
    case overworked
    case burnout
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
/// behavioral `BitzState`, thermal override banner, and Rive state machine synchronization.
@MainActor
public final class WellnessPointEngine: ObservableObject {
    public static let thermalWarningText = "SYSTEM HOT! > <"
    public static let productiveTickDelta: Double = 0.5
    public static let unproductiveTickDelta: Double = -1.5
    public static let offlineBreakMinThresholdMinutes: Double = 10.0
    public static let offlineBreakPointsPerMinute: Double = 5.0

    @Published public private(set) var currentPoints: Double = 50.0
    @Published public private(set) var currentState: BitzState = .balanced
    @Published public private(set) var activeSpeechBubbleText: String? = nil

    public let maxPoints: Double = 100.0
    public let minPoints: Double = 0.0

    public var riveController: BitzRiveControllable?
    private var isOverheatingOverride: Bool = false

    public init(
        initialPoints: Double = 50.0,
        riveController: BitzRiveControllable? = nil
    ) {
        self.riveController = riveController
        self.currentPoints = min(max(initialPoints, minPoints), maxPoints)
        evaluateState()
    }

    /// Evaluates a single work tick (`+0.5` for productive apps, `-1.5` for unproductive apps),
    /// clamps `currentPoints` within `0.0...100.0`, and synchronizes the state machine.
    public func evaluateWorkTick(isProductiveApp: Bool) {
        let delta = isProductiveApp ? Self.productiveTickDelta : Self.unproductiveTickDelta
        currentPoints = min(max(currentPoints + delta, minPoints), maxPoints)
        if !isOverheatingOverride {
            evaluateState()
        }
    }

    /// Restores `+5.0` points per minute when the offline break exceeds `10.0` minutes,
    /// clamps `currentPoints` within `0.0...100.0`, and synchronizes the state machine.
    public func applyOfflineBreak(minutes: Double) {
        guard minutes > Self.offlineBreakMinThresholdMinutes else { return }
        let restoredPoints = minutes * Self.offlineBreakPointsPerMinute
        currentPoints = min(max(currentPoints + restoredPoints, minPoints), maxPoints)
        if !isOverheatingOverride {
            evaluateState()
        }
    }

    /// Triggers or clears the `.overheating` state override and `"SYSTEM HOT! > <"` speech bubble.
    /// When `isOverheating` is `false`, restores the underlying point-derived `BitzState`.
    public func triggerThermalWarning(isOverheating: Bool) {
        if isOverheating {
            isOverheatingOverride = true
            currentState = .overheating
            activeSpeechBubbleText = Self.thermalWarningText
            syncWithRive()
        } else {
            isOverheatingOverride = false
            activeSpeechBubbleText = nil
            evaluateState()
        }
    }

    /// Fires the Rive `"triggerPet"` interaction input.
    public func triggerPetInteraction() {
        riveController?.triggerInput(BitzRiveInputName.triggerPet)
    }

    /// Evaluates the point-derived `BitzState` from `currentPoints` and synchronizes Rive inputs.
    public func evaluateState() {
        let newState = Self.state(forPoints: currentPoints)
        currentState = newState
        syncWithRive()
    }

    /// Pure threshold mapping from `points` (`0.0...100.0`) to a non-overheating `BitzState`.
    public static func state(forPoints points: Double) -> BitzState {
        switch points {
        case 80.0...100.0:
            return .superCharged
        case 40.0..<80.0:
            return .balanced
        case 15.0..<40.0:
            return .overworked
        default:
            return .burnout
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

        case .overworked:
            rive.setInput(BitzRiveInputName.speedMultiplier, value: Float(0.4))
            rive.setInput(BitzRiveInputName.visorColor, value: BitzVisorColor.amber)
            rive.setInput(BitzRiveInputName.isGlitching, value: false)
            rive.setInput(BitzRiveInputName.isStandby, value: false)

        case .burnout:
            rive.setInput(BitzRiveInputName.speedMultiplier, value: Float(0.0))
            rive.setInput(BitzRiveInputName.isStandby, value: true)
            rive.setInput(BitzRiveInputName.isGlitching, value: false)

        case .overheating:
            rive.setInput(BitzRiveInputName.isGlitching, value: true)
            rive.setInput(BitzRiveInputName.visorColor, value: BitzVisorColor.red)
        }
    }
}
