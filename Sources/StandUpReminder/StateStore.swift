import Foundation
import ReminderCore

final class StateStore {
    private struct StoredConfiguration: Codable {
        let version: Int
        let workDuration: TimeInterval
        let standingDuration: TimeInterval
    }

    private enum Key {
        static let snapshot = "reminder.snapshot"
        static let completedDate = "reminder.completed.date"
        static let completedCount = "reminder.completed.count"
        static let configuration = "reminder.configuration.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let calendar: Calendar

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func loadSnapshot() -> ReminderSnapshot? {
        guard
            let data = defaults.data(forKey: Key.snapshot),
            let snapshot = try? decoder.decode(ReminderSnapshot.self, from: data)
        else {
            return nil
        }

        return snapshot
    }

    func save(snapshot: ReminderSnapshot) {
        guard let data = try? encoder.encode(snapshot) else {
            return
        }

        defaults.set(data, forKey: Key.snapshot)
    }

    func loadConfiguration() -> ReminderConfiguration {
        guard
            let data = defaults.data(forKey: Key.configuration),
            let stored = try? decoder.decode(StoredConfiguration.self, from: data),
            stored.version == 1,
            (5 * 60 ... 4 * 60 * 60).contains(stored.workDuration),
            (1 * 60 ... 60 * 60).contains(stored.standingDuration)
        else {
            return .standard
        }

        return ReminderConfiguration(
            workDuration: stored.workDuration,
            standingDuration: stored.standingDuration
        )
    }

    func save(configuration: ReminderConfiguration) {
        let stored = StoredConfiguration(
            version: 1,
            workDuration: configuration.workDuration,
            standingDuration: configuration.standingDuration
        )

        guard let data = try? encoder.encode(stored) else {
            return
        }

        defaults.set(data, forKey: Key.configuration)
    }

    func completedCount(on date: Date = Date()) -> Int {
        resetCountIfNeeded(on: date)
        return defaults.integer(forKey: Key.completedCount)
    }

    @discardableResult
    func recordCompletion(on date: Date = Date()) -> Int {
        resetCountIfNeeded(on: date)
        let updatedCount = defaults.integer(forKey: Key.completedCount) + 1
        defaults.set(updatedCount, forKey: Key.completedCount)
        return updatedCount
    }

    private func resetCountIfNeeded(on date: Date) {
        let startOfToday = calendar.startOfDay(for: date)
        let recordedDate = defaults.object(forKey: Key.completedDate) as? Date

        guard recordedDate.map({ calendar.isDate($0, inSameDayAs: date) }) != true else {
            return
        }

        defaults.set(startOfToday, forKey: Key.completedDate)
        defaults.set(0, forKey: Key.completedCount)
    }
}
