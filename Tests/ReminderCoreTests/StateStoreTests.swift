import Foundation
import XCTest
@testable import ReminderCore
@testable import StandUpReminder

final class StateStoreTests: XCTestCase {
    func testMissingConfigurationUsesStandardDurations() {
        withIsolatedDefaults { defaults in
            let store = StateStore(defaults: defaults)

            XCTAssertEqual(store.loadConfiguration(), .standard)
        }
    }

    func testConfigurationPersistsAcrossStoreInstances() {
        withIsolatedDefaults { defaults in
            let configuration = ReminderConfiguration(
                workDuration: 25 * 60,
                standingDuration: 3 * 60
            )

            StateStore(defaults: defaults).save(configuration: configuration)
            let restored = StateStore(defaults: defaults).loadConfiguration()

            XCTAssertEqual(restored, configuration)
        }
    }

    func testDamagedConfigurationUsesStandardDurations() {
        withIsolatedDefaults { defaults in
            defaults.set(
                Data("not-json".utf8),
                forKey: "reminder.configuration.v1"
            )

            XCTAssertEqual(
                StateStore(defaults: defaults).loadConfiguration(),
                .standard
            )
        }
    }

    func testOutOfRangeConfigurationUsesStandardDurations() {
        withIsolatedDefaults { defaults in
            let invalidJSON = """
            {
              "version": 1,
              "workDuration": 0,
              "standingDuration": -60
            }
            """
            defaults.set(
                Data(invalidJSON.utf8),
                forKey: "reminder.configuration.v1"
            )

            XCTAssertEqual(
                StateStore(defaults: defaults).loadConfiguration(),
                .standard
            )
        }
    }

    func testPausedSnapshotPersistsAcrossStoreInstances() {
        withIsolatedDefaults { defaults in
            let savedAt = Date(timeIntervalSince1970: 1_000)
            let snapshot = ReminderSnapshot(
                phase: .paused,
                remaining: 1_234,
                savedAt: savedAt
            )

            StateStore(defaults: defaults).save(snapshot: snapshot)
            let restored = StateStore(defaults: defaults).loadSnapshot()

            XCTAssertEqual(restored, snapshot)
        }
    }

    private func withIsolatedDefaults(
        _ body: (UserDefaults) throws -> Void
    ) rethrows {
        let suiteName = "StateStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }
}
