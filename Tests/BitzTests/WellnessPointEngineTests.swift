import XCTest
@testable import BitzCore

@MainActor
final class WellnessPointEngineTests: XCTestCase {

    // MARK: - Contract SSOT Mirror Assertions

    func testRiveContractConstantsMatchSpecificationByteForByte() {
        XCTAssertEqual(BitzRiveInputName.stateMachineName, "BitzStateMachine")
        XCTAssertEqual(BitzRiveInputName.speedMultiplier, "speedMultiplier")
        XCTAssertEqual(BitzRiveInputName.visorColor, "visorColor")
        XCTAssertEqual(BitzRiveInputName.isStandby, "isStandby")
        XCTAssertEqual(BitzRiveInputName.isGlitching, "isGlitching")
        XCTAssertEqual(BitzRiveInputName.triggerPet, "triggerPet")
        XCTAssertEqual(
            BitzRiveInputName.allInputNames,
            Set(["speedMultiplier", "visorColor", "isStandby", "isGlitching", "triggerPet"])
        )

        XCTAssertEqual(BitzVisorColor.cyan, 0.0)
        XCTAssertEqual(BitzVisorColor.magenta, 1.0)
        XCTAssertEqual(BitzVisorColor.amber, 2.0)
        XCTAssertEqual(BitzVisorColor.red, 3.0)

        XCTAssertEqual(
            Set(BitzState.allCases.map(\.rawValue)),
            Set(["superCharged", "balanced", "overworked", "burnout", "overheating"])
        )
        XCTAssertEqual(WellnessPointEngine.thermalWarningText, "SYSTEM HOT! > <")
    }

    // MARK: - Initial State & Clamping

    func testInitialDefaultStateIsBalancedAtFiftyPoints() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(riveController: spy)

        XCTAssertEqual(engine.currentPoints, 50.0, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .balanced)
        XCTAssertNil(engine.activeSpeechBubbleText)
        XCTAssertEqual(engine.minPoints, 0.0)
        XCTAssertEqual(engine.maxPoints, 100.0)

        XCTAssertEqual(spy.floatInputs["speedMultiplier"], 1.0)
        XCTAssertEqual(spy.floatInputs["visorColor"], 0.0)
        XCTAssertEqual(spy.boolInputs["isStandby"], false)
        XCTAssertEqual(spy.boolInputs["isGlitching"], false)
    }

    func testInitialPointsClampToZeroAndOneHundred() {
        let spyLow = SpyRiveController()
        let lowEngine = WellnessPointEngine(initialPoints: -25.0, riveController: spyLow)
        XCTAssertEqual(lowEngine.currentPoints, 0.0, accuracy: 0.0001)
        XCTAssertEqual(lowEngine.currentState, .burnout)
        XCTAssertEqual(spyLow.floatInputs["speedMultiplier"], 0.0)
        XCTAssertEqual(spyLow.boolInputs["isStandby"], true)

        let spyHigh = SpyRiveController()
        let highEngine = WellnessPointEngine(initialPoints: 150.0, riveController: spyHigh)
        XCTAssertEqual(highEngine.currentPoints, 100.0, accuracy: 0.0001)
        XCTAssertEqual(highEngine.currentState, .superCharged)
        XCTAssertEqual(spyHigh.floatInputs["speedMultiplier"], 2.0)
        XCTAssertEqual(spyHigh.floatInputs["visorColor"], 1.0)
    }

    // MARK: - Work Ticks & Clamping

    func testProductiveWorkTickAddsHalfPointAndTransitionsToSuperCharged() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 79.5, riveController: spy)
        XCTAssertEqual(engine.currentState, .balanced)

        engine.evaluateWorkTick(isProductiveApp: true)
        XCTAssertEqual(engine.currentPoints, 80.0, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .superCharged)
        XCTAssertEqual(spy.floatInputs["speedMultiplier"], 2.0)
        XCTAssertEqual(spy.floatInputs["visorColor"], 1.0)
        XCTAssertEqual(spy.boolInputs["isGlitching"], false)
        XCTAssertEqual(spy.boolInputs["isStandby"], false)
    }

    func testProductiveWorkTickClampsAtOneHundredPoints() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 99.8, riveController: spy)

        engine.evaluateWorkTick(isProductiveApp: true)
        XCTAssertEqual(engine.currentPoints, 100.0, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .superCharged)

        engine.evaluateWorkTick(isProductiveApp: true)
        XCTAssertEqual(engine.currentPoints, 100.0, accuracy: 0.0001)
    }

    func testUnproductiveWorkTickSubtractsOneAndHalfPointsAcrossAllThresholds() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 41.0, riveController: spy)
        XCTAssertEqual(engine.currentState, .balanced)

        // 41.0 - 1.5 = 39.5 -> Overworked
        engine.evaluateWorkTick(isProductiveApp: false)
        XCTAssertEqual(engine.currentPoints, 39.5, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .overworked)
        XCTAssertEqual(spy.floatInputs["speedMultiplier"], 0.4)
        XCTAssertEqual(spy.floatInputs["visorColor"], 2.0)
        XCTAssertEqual(spy.boolInputs["isGlitching"], false)
        XCTAssertEqual(spy.boolInputs["isStandby"], false)
    }

    func testUnproductiveWorkTickTransitionsToBurnoutAndClampsAtZero() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 15.5, riveController: spy)
        XCTAssertEqual(engine.currentState, .overworked)

        // 15.5 - 1.5 = 14.0 -> Burnout (< 15.0)
        engine.evaluateWorkTick(isProductiveApp: false)
        XCTAssertEqual(engine.currentPoints, 14.0, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .burnout)
        XCTAssertEqual(spy.floatInputs["speedMultiplier"], 0.0)
        XCTAssertEqual(spy.boolInputs["isStandby"], true)
        XCTAssertEqual(spy.boolInputs["isGlitching"], false)

        // Drain all the way to 0.0 and verify floor clamp
        for _ in 0..<15 {
            engine.evaluateWorkTick(isProductiveApp: false)
        }
        XCTAssertEqual(engine.currentPoints, 0.0, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .burnout)
    }

    // MARK: - Exact Boundary Thresholds

    func testExactBoundaryThresholds() {
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 100.0), .superCharged)
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 80.0), .superCharged)
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 79.999), .balanced)
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 40.0), .balanced)
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 39.999), .overworked)
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 15.0), .overworked)
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 14.999), .burnout)
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 0.0), .burnout)
    }

    // MARK: - Offline Break Restoration

    func testOfflineBreakTenMinutesOrLessAddsZeroPoints() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 20.0, riveController: spy)
        spy.resetRecordedCommands()

        engine.applyOfflineBreak(minutes: 0.0)
        XCTAssertEqual(engine.currentPoints, 20.0, accuracy: 0.0001)
        XCTAssertTrue(spy.commands.isEmpty)

        engine.applyOfflineBreak(minutes: 10.0)
        XCTAssertEqual(engine.currentPoints, 20.0, accuracy: 0.0001)
        XCTAssertTrue(spy.commands.isEmpty)
    }

    func testOfflineBreakGreaterThanTenMinutesRestoresFivePointsPerMinuteAndClamps() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 10.0, riveController: spy)
        XCTAssertEqual(engine.currentState, .burnout)

        // 11 minutes > 10.0 -> +55.0 pts -> 65.0 pts (.balanced)
        engine.applyOfflineBreak(minutes: 11.0)
        XCTAssertEqual(engine.currentPoints, 65.0, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .balanced)
        XCTAssertEqual(spy.floatInputs["speedMultiplier"], 1.0)
        XCTAssertEqual(spy.floatInputs["visorColor"], 0.0)
        XCTAssertEqual(spy.boolInputs["isStandby"], false)

        // 15 minutes -> +75.0 pts -> clamped to 100.0 (.superCharged)
        engine.applyOfflineBreak(minutes: 15.0)
        XCTAssertEqual(engine.currentPoints, 100.0, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .superCharged)
    }

    // MARK: - Thermal Warning Override & Recovery

    func testThermalWarningOverridesStateAndRestoresUnderlyingStateWhenCleared() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 85.0, riveController: spy)
        XCTAssertEqual(engine.currentState, .superCharged)
        XCTAssertNil(engine.activeSpeechBubbleText)

        // Trigger thermal warning
        engine.triggerThermalWarning(isOverheating: true)
        XCTAssertEqual(engine.currentState, .overheating)
        XCTAssertEqual(engine.activeSpeechBubbleText, "SYSTEM HOT! > <")
        XCTAssertEqual(spy.boolInputs["isGlitching"], true)
        XCTAssertEqual(spy.floatInputs["visorColor"], 3.0)

        // While overheating, work ticks update points but preserve .overheating override
        engine.evaluateWorkTick(isProductiveApp: false)
        XCTAssertEqual(engine.currentPoints, 83.5, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .overheating)

        // Clear thermal warning -> restores .superCharged (83.5 pts)
        engine.triggerThermalWarning(isOverheating: false)
        XCTAssertEqual(engine.currentState, .superCharged)
        XCTAssertNil(engine.activeSpeechBubbleText)
        XCTAssertEqual(spy.boolInputs["isGlitching"], false)
        XCTAssertEqual(spy.floatInputs["visorColor"], 1.0)
        XCTAssertEqual(spy.floatInputs["speedMultiplier"], 2.0)
    }

    // MARK: - Pet Interaction Trigger & ProductionRiveController

    func testTriggerPetInteractionFiresRiveTriggerPetInput() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(riveController: spy)

        engine.triggerPetInteraction()
        engine.triggerPetInteraction()

        XCTAssertEqual(spy.triggerCounts["triggerPet"], 2)
        XCTAssertEqual(spy.commands.last, .fireTrigger("triggerPet"))
    }

    func testProductionRiveControllerStoresInputsAndInvokesCallback() {
        var dispatched: [BitzRiveCommand] = []
        let controller = ProductionRiveController { command in
            dispatched.append(command)
        }
        let engine = WellnessPointEngine(initialPoints: 50.0, riveController: controller)

        XCTAssertEqual(controller.fileName, "bitz_cyber_cat")
        XCTAssertEqual(controller.stateMachineName, "BitzStateMachine")
        XCTAssertEqual(controller.floatInputs["speedMultiplier"], 1.0)
        XCTAssertEqual(controller.floatInputs["visorColor"], 0.0)
        XCTAssertEqual(controller.boolInputs["isStandby"], false)
        XCTAssertEqual(controller.boolInputs["isGlitching"], false)

        engine.triggerPetInteraction()
        XCTAssertEqual(controller.lastTriggeredInput, "triggerPet")
        XCTAssertEqual(controller.totalTriggerCount, 1)
        XCTAssertTrue(dispatched.contains(.fireTrigger("triggerPet")))
    }
}
