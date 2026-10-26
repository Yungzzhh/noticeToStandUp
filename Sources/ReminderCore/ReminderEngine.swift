import Foundation

public struct ReminderConfiguration: Equatable, Sendable {
    public let workDuration: TimeInterval
    public let standingDuration: TimeInterval

    public init(
        workDuration: TimeInterval = 60 * 60,
        standingDuration: TimeInterval = 5 * 60
    ) {
        precondition(workDuration > 0)
        precondition(standingDuration > 0)

        self.workDuration = workDuration
        self.standingDuration = standingDuration
    }

    public static let standard = ReminderConfiguration()
}

public enum ReminderPhase: String, Codable, Equatable, Sendable {
    case working
    case standing
    case paused
}

public enum ReminderTransition: Equatable, Sendable {
    case none
    case standingStarted
    case standingCompleted
    case standingEndedEarly
    case workPaused
    case workResumed
}

public struct ReminderSnapshot: Codable, Equatable, Sendable {
    public let phase: ReminderPhase
    public let remaining: TimeInterval
    public let savedAt: Date

    public init(phase: ReminderPhase, remaining: TimeInterval, savedAt: Date) {
        self.phase = phase
        self.remaining = remaining
        self.savedAt = savedAt
    }
}

public struct ReminderEngine: Equatable, Sendable {
    public private(set) var configuration: ReminderConfiguration
    public private(set) var phase: ReminderPhase
    public private(set) var remaining: TimeInterval

    public init(configuration: ReminderConfiguration = .standard) {
        self.configuration = configuration
        self.phase = .working
        self.remaining = configuration.workDuration
    }

    public init(
        configuration: ReminderConfiguration = .standard,
        snapshot: ReminderSnapshot?,
        resumedAt now: Date
    ) {
        self.init(configuration: configuration)

        guard let snapshot else {
            return
        }

        if snapshot.phase == .paused {
            phase = .paused
            remaining = clampedRemaining(
                snapshot.remaining,
                maximum: configuration.workDuration
            )
            return
        }

        let inactiveDuration = max(0, now.timeIntervalSince(snapshot.savedAt))

        // 离开电脑达到完整休息时长，就视为已经离开座位活动过。
        guard inactiveDuration < configuration.standingDuration else {
            return
        }

        switch snapshot.phase {
        case .working:
            phase = .working
            remaining = clampedRemaining(
                snapshot.remaining,
                maximum: configuration.workDuration
            )

        case .standing:
            let resumedRemaining = snapshot.remaining - inactiveDuration

            guard resumedRemaining > 0 else {
                return
            }

            phase = .standing
            remaining = clampedRemaining(
                resumedRemaining,
                maximum: configuration.standingDuration
            )

        case .paused:
            return
        }
    }

    @discardableResult
    public mutating func advance(by elapsed: TimeInterval) -> ReminderTransition {
        guard elapsed.isFinite, elapsed > 0 else {
            return .none
        }

        guard phase != .paused else {
            return .none
        }

        remaining = max(0, remaining - elapsed)

        guard remaining == 0 else {
            return .none
        }

        switch phase {
        case .working:
            phase = .standing
            remaining = configuration.standingDuration
            return .standingStarted

        case .standing:
            phase = .working
            remaining = configuration.workDuration
            return .standingCompleted

        case .paused:
            return .none
        }
    }

    @discardableResult
    public mutating func beginStandingNow() -> ReminderTransition {
        guard phase == .working else {
            return .none
        }

        phase = .standing
        remaining = configuration.standingDuration
        return .standingStarted
    }

    @discardableResult
    public mutating func endStandingEarly() -> ReminderTransition {
        guard phase == .standing else {
            return .none
        }

        phase = .working
        remaining = configuration.workDuration
        return .standingEndedEarly
    }

    @discardableResult
    public mutating func pauseWork() -> ReminderTransition {
        guard phase == .working else {
            return .none
        }

        phase = .paused
        return .workPaused
    }

    @discardableResult
    public mutating func resumeWork() -> ReminderTransition {
        guard phase == .paused else {
            return .none
        }

        phase = .working
        return .workResumed
    }

    @discardableResult
    public mutating func applyConfiguration(
        _ newConfiguration: ReminderConfiguration
    ) -> ReminderTransition {
        guard phase == .working else {
            return .none
        }

        let elapsedWork = max(0, configuration.workDuration - remaining)
        configuration = newConfiguration
        let updatedRemaining = newConfiguration.workDuration - elapsedWork

        guard updatedRemaining > 0 else {
            phase = .standing
            remaining = newConfiguration.standingDuration
            return .standingStarted
        }

        remaining = updatedRemaining
        return .none
    }

    public mutating func resetWorkCycle() {
        phase = .working
        remaining = configuration.workDuration
    }

    public func snapshot(at date: Date) -> ReminderSnapshot {
        ReminderSnapshot(phase: phase, remaining: remaining, savedAt: date)
    }

    public var roundedRemainingSeconds: Int {
        max(0, Int(ceil(remaining)))
    }

    private func clampedRemaining(
        _ value: TimeInterval,
        maximum: TimeInterval
    ) -> TimeInterval {
        min(max(value, 1), maximum)
    }
}
