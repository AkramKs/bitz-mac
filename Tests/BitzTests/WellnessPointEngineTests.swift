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
        XCTAssertEqual(BitzVisorColor.purple, 4.0)
        XCTAssertEqual(BitzVisorColor.green, 5.0)

        XCTAssertEqual(
            Set(BitzState.allCases.map(\.rawValue)),
            Set(["superCharged", "balanced", "dopamineSad", "overworked", "burnout", "charging", "overheating"])
        )
        XCTAssertEqual(WellnessPointEngine.thermalWarningText, "🔥 SYSTEM HOT! CLOSE HEAVY APPS TO COOL DOWN")
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
        XCTAssertEqual(lowEngine.currentState, .dopamineSad)
        XCTAssertEqual(spyLow.floatInputs["speedMultiplier"], 0.35)
        XCTAssertEqual(spyLow.floatInputs["visorColor"], BitzVisorColor.purple)

        let spyHigh = SpyRiveController()
        let highEngine = WellnessPointEngine(initialPoints: 150.0, riveController: spyHigh)
        XCTAssertEqual(highEngine.currentPoints, 100.0, accuracy: 0.0001)
        XCTAssertEqual(highEngine.currentState, .superCharged)
        XCTAssertEqual(spyHigh.floatInputs["speedMultiplier"], 2.0)
        XCTAssertEqual(spyHigh.floatInputs["visorColor"], 1.0)
    }

    // MARK: - Work Ticks, Dopamine Sad & Continuous Work Burnout

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

    func testUnproductiveWorkTickDrainsIntoDopamineSadAndClampsAtZero() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 41.0, riveController: spy)
        XCTAssertEqual(engine.currentState, .balanced)

        // 41.0 - 1.5 = 39.5 -> .dopamineSad (Too much YouTube/Netflix)
        engine.evaluateWorkTick(isProductiveApp: false)
        XCTAssertEqual(engine.currentPoints, 39.5, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .dopamineSad)
        XCTAssertEqual(engine.activeSpeechBubbleText, WellnessPointEngine.dopamineSadText)
        XCTAssertEqual(spy.floatInputs["speedMultiplier"], 0.35)
        XCTAssertEqual(spy.floatInputs["visorColor"], BitzVisorColor.purple)

        for _ in 0..<30 {
            engine.evaluateWorkTick(isProductiveApp: false)
        }
        XCTAssertEqual(engine.currentPoints, 0.0, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .dopamineSad)
    }

    func testContinuousWorkWithoutBreakTriggersOverworkedAndBurnout() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 80.0, riveController: spy)
        XCTAssertEqual(engine.currentState, .superCharged)

        // Work 45 minutes continuously without a break -> .overworked
        engine.evaluateWorkTick(isProductiveApp: true, tickDurationMinutes: 45.0)
        XCTAssertEqual(engine.currentState, .overworked)
        XCTAssertEqual(engine.activeSpeechBubbleText, WellnessPointEngine.overworkedWarningText)
        XCTAssertEqual(spy.floatInputs["visorColor"], BitzVisorColor.amber)

        // Work another 45 minutes (total 90m) -> .burnout
        engine.evaluateWorkTick(isProductiveApp: true, tickDurationMinutes: 45.0)
        XCTAssertEqual(engine.currentState, .burnout)
        XCTAssertEqual(engine.activeSpeechBubbleText, WellnessPointEngine.burnoutWarningText)
        XCTAssertEqual(spy.boolInputs["isStandby"], true)
    }

    // MARK: - Exact Boundary Thresholds

    func testExactBoundaryThresholds() {
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 100.0), .superCharged)
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 80.0), .superCharged)
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 79.999), .balanced)
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 40.0), .balanced)
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 39.999), .dopamineSad)
        XCTAssertEqual(WellnessPointEngine.state(forPoints: 0.0), .dopamineSad)
    }

    // MARK: - Charging & Offline Break Restoration

    func testChargingStateAndOfflineBreakRestoration() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 30.0, initialContinuousWorkMinutes: 95.0, riveController: spy)
        XCTAssertEqual(engine.currentState, .burnout)

        // User steps away from keyboard -> .charging
        engine.setChargingState(true)
        XCTAssertEqual(engine.currentState, .charging)
        XCTAssertEqual(engine.activeSpeechBubbleText, WellnessPointEngine.chargingStatusText)
        XCTAssertEqual(spy.floatInputs["visorColor"], BitzVisorColor.green)
        XCTAssertEqual(engine.currentPoints, 30.5, accuracy: 0.0001)

        // Return after 5 minutes (> 2.0m threshold) -> +25.0 pts (55.5) and resets continuousWorkMinutes to 0
        engine.applyOfflineBreak(minutes: 5.0)
        XCTAssertEqual(engine.currentPoints, 55.5, accuracy: 0.0001)
        XCTAssertEqual(engine.continuousWorkMinutes, 0.0, accuracy: 0.0001)
        XCTAssertEqual(engine.currentState, .balanced)
        XCTAssertNil(engine.activeSpeechBubbleText)
    }

    // MARK: - Thermal Warning Override & Recovery

    func testThermalWarningOverridesStateAndRestoresUnderlyingStateWhenCleared() {
        let spy = SpyRiveController()
        let engine = WellnessPointEngine(initialPoints: 85.0, riveController: spy)
        XCTAssertEqual(engine.currentState, .superCharged)
        XCTAssertNil(engine.activeSpeechBubbleText)

        // Trigger thermal warning with actionable message
        engine.triggerThermalWarning(
            isOverheating: true,
            actionMessage: "🔥 85°C — CLOSE HEAVY APPS TO COOL DOWN!"
        )
        XCTAssertEqual(engine.currentState, .overheating)
        XCTAssertEqual(engine.activeSpeechBubbleText, "🔥 85°C — CLOSE HEAVY APPS TO COOL DOWN!")
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
