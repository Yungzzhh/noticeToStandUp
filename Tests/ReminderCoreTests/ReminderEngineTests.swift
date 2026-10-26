import Foundation
import XCTest
@testable import ReminderCore

final class ReminderEngineTests: XCTestCase {
    private let configuration = ReminderConfiguration(
        workDuration: 60 * 60,
        standingDuration: 5 * 60
    )

    func testStartsWithOneHourWorkCycle() {
        let engine = ReminderEngine(configuration: configuration)

        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.remaining, 3_600)
    }

    func testWorkCycleStartsStandingAtExactlyOneHour() {
        var engine = ReminderEngine(configuration: configuration)

        XCTAssertEqual(engine.advance(by: 3_599), .none)
        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.advance(by: 1), .standingStarted)
        XCTAssertEqual(engine.phase, .standing)
        XCTAssertEqual(engine.remaining, 300)
    }

    func testStandingCycleCompletesAtExactlyFiveMinutes() {
        var engine = ReminderEngine(configuration: configuration)
        engine.beginStandingNow()

        XCTAssertEqual(engine.advance(by: 299), .none)
        XCTAssertEqual(engine.phase, .standing)
        XCTAssertEqual(engine.advance(by: 1), .standingCompleted)
        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.remaining, 3_600)
    }

    func testManualStandingCannotRestartAnActiveStandingCycle() {
        var engine = ReminderEngine(configuration: configuration)

        XCTAssertEqual(engine.beginStandingNow(), .standingStarted)
        XCTAssertEqual(engine.advance(by: 60), .none)
        XCTAssertEqual(engine.beginStandingNow(), .none)
        XCTAssertEqual(engine.remaining, 240)
    }

    func testEndingStandingEarlyStartsFreshWorkCycle() {
        var engine = ReminderEngine(configuration: configuration)
        engine.beginStandingNow()
        engine.advance(by: 90)

        XCTAssertEqual(engine.endStandingEarly(), .standingEndedEarly)
        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.remaining, configuration.workDuration)
    }

    func testEndingStandingEarlyWhileWorkingDoesNothing() {
        var engine = ReminderEngine(configuration: configuration)
        engine.advance(by: 20 * 60)

        XCTAssertEqual(engine.endStandingEarly(), .none)
        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.remaining, 40 * 60)
    }

    func testPausingWorkFreezesRemainingTime() {
        var engine = ReminderEngine(configuration: configuration)
        engine.advance(by: 20 * 60)

        XCTAssertEqual(engine.pauseWork(), .workPaused)
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertEqual(engine.advance(by: 3 * 60 * 60), .none)
        XCTAssertEqual(engine.remaining, 40 * 60)
    }

    func testResumingWorkContinuesFromPausedRemainingTime() {
        var engine = ReminderEngine(configuration: configuration)
        engine.advance(by: 20 * 60)
        engine.pauseWork()

        XCTAssertEqual(engine.resumeWork(), .workResumed)
        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.advance(by: 10 * 60), .none)
        XCTAssertEqual(engine.remaining, 30 * 60)
    }

    func testStandingCycleCannotBePausedOrResumed() {
        var engine = ReminderEngine(configuration: configuration)
        engine.beginStandingNow()

        XCTAssertEqual(engine.pauseWork(), .none)
        XCTAssertEqual(engine.resumeWork(), .none)
        XCTAssertEqual(engine.phase, .standing)
        XCTAssertEqual(engine.remaining, configuration.standingDuration)
    }

    func testPausedSnapshotSurvivesLongInterruption() {
        let savedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = ReminderSnapshot(
            phase: .paused,
            remaining: 1_234,
            savedAt: savedAt
        )

        let engine = ReminderEngine(
            configuration: configuration,
            snapshot: snapshot,
            resumedAt: savedAt.addingTimeInterval(24 * 60 * 60)
        )

        XCTAssertEqual(engine.phase, .paused)
        XCTAssertEqual(engine.remaining, 1_234)
    }

    func testRepeatedPauseAndResumeRequestsDoNothing() {
        var engine = ReminderEngine(configuration: configuration)

        XCTAssertEqual(engine.pauseWork(), .workPaused)
        XCTAssertEqual(engine.pauseWork(), .none)
        XCTAssertEqual(engine.resumeWork(), .workResumed)
        XCTAssertEqual(engine.resumeWork(), .none)
        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.remaining, configuration.workDuration)
    }

    func testPausedWorkRejectsStandingAndConfigurationChanges() {
        var engine = ReminderEngine(configuration: configuration)
        engine.advance(by: 20 * 60)
        engine.pauseWork()
        let updatedConfiguration = ReminderConfiguration(
            workDuration: 90 * 60,
            standingDuration: 3 * 60
        )

        XCTAssertEqual(engine.beginStandingNow(), .none)
        XCTAssertEqual(engine.applyConfiguration(updatedConfiguration), .none)
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertEqual(engine.remaining, 40 * 60)
        XCTAssertEqual(engine.configuration, configuration)
    }

    func testApplyingLongerWorkDurationPreservesElapsedWork() {
        var engine = ReminderEngine(configuration: configuration)
        engine.advance(by: 20 * 60)

        let transition = engine.applyConfiguration(
            ReminderConfiguration(
                workDuration: 90 * 60,
                standingDuration: 3 * 60
            )
        )

        XCTAssertEqual(transition, .none)
        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.remaining, 70 * 60)
        XCTAssertEqual(engine.configuration.workDuration, 90 * 60)
        XCTAssertEqual(engine.configuration.standingDuration, 3 * 60)
    }

    func testShorteningWorkDurationPastElapsedTimeStartsStanding() {
        var engine = ReminderEngine(configuration: configuration)
        engine.advance(by: 40 * 60)

        let transition = engine.applyConfiguration(
            ReminderConfiguration(
                workDuration: 30 * 60,
                standingDuration: 3 * 60
            )
        )

        XCTAssertEqual(transition, .standingStarted)
        XCTAssertEqual(engine.phase, .standing)
        XCTAssertEqual(engine.remaining, 3 * 60)
    }

    func testStandingCycleRejectsConfigurationChanges() {
        var engine = ReminderEngine(configuration: configuration)
        engine.beginStandingNow()
        engine.advance(by: 60)

        let transition = engine.applyConfiguration(
            ReminderConfiguration(
                workDuration: 25 * 60,
                standingDuration: 1 * 60
            )
        )

        XCTAssertEqual(transition, .none)
        XCTAssertEqual(engine.configuration, configuration)
        XCTAssertEqual(engine.phase, .standing)
        XCTAssertEqual(engine.remaining, 4 * 60)
    }

    func testUpdatedConfigurationControlsFollowingCycles() {
        var engine = ReminderEngine(configuration: configuration)
        let updatedConfiguration = ReminderConfiguration(
            workDuration: 25 * 60,
            standingDuration: 3 * 60
        )

        engine.applyConfiguration(updatedConfiguration)
        XCTAssertEqual(engine.beginStandingNow(), .standingStarted)
        XCTAssertEqual(engine.remaining, 3 * 60)
        XCTAssertEqual(engine.advance(by: 3 * 60), .standingCompleted)
        XCTAssertEqual(engine.remaining, 25 * 60)
    }

    func testShortAppInterruptionPreservesWorkingTime() {
        let savedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = ReminderSnapshot(
            phase: .working,
            remaining: 1_234,
            savedAt: savedAt
        )

        let engine = ReminderEngine(
            configuration: configuration,
            snapshot: snapshot,
            resumedAt: savedAt.addingTimeInterval(120)
        )

        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.remaining, 1_234)
    }

    func testShortAppInterruptionCountsTowardStandingTime() {
        let savedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = ReminderSnapshot(
            phase: .standing,
            remaining: 240,
            savedAt: savedAt
        )

        let engine = ReminderEngine(
            configuration: configuration,
            snapshot: snapshot,
            resumedAt: savedAt.addingTimeInterval(120)
        )

        XCTAssertEqual(engine.phase, .standing)
        XCTAssertEqual(engine.remaining, 120)
    }

    func testFiveMinuteInterruptionStartsFreshWorkCycle() {
        let savedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = ReminderSnapshot(
            phase: .working,
            remaining: 30,
            savedAt: savedAt
        )

        let engine = ReminderEngine(
            configuration: configuration,
            snapshot: snapshot,
            resumedAt: savedAt.addingTimeInterval(300)
        )

        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.remaining, 3_600)
    }

    func testClockRollbackDoesNotConsumeRemainingTime() {
        let savedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = ReminderSnapshot(
            phase: .working,
            remaining: 900,
            savedAt: savedAt
        )

        let engine = ReminderEngine(
            configuration: configuration,
            snapshot: snapshot,
            resumedAt: savedAt.addingTimeInterval(-120)
        )

        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.remaining, 900)
    }

    func testInvalidElapsedTimeDoesNotChangeState() {
        var engine = ReminderEngine(configuration: configuration)

        XCTAssertEqual(engine.advance(by: -10), .none)
        XCTAssertEqual(engine.advance(by: .infinity), .none)
        XCTAssertEqual(engine.remaining, 3_600)
    }
}
