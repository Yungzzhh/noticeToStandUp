namespace StandUpReminder.Core;

public enum ReminderPhase
{
    Working,
    Standing,
    Paused
}

public enum ReminderTransition
{
    None,
    StandingStarted,
    StandingCompleted,
    StandingEndedEarly,
    WorkPaused,
    WorkResumed
}

public sealed record ReminderSnapshot(
    ReminderPhase Phase,
    TimeSpan Remaining,
    DateTimeOffset SavedAt);

public sealed class ReminderEngine
{
    public ReminderEngine(ReminderConfiguration? configuration = null)
    {
        Configuration = configuration ?? ReminderConfiguration.Standard;
        Phase = ReminderPhase.Working;
        Remaining = Configuration.WorkDuration;
    }

    public ReminderEngine(
        ReminderConfiguration configuration,
        ReminderSnapshot? snapshot,
        DateTimeOffset resumedAt)
        : this(configuration)
    {
        if (snapshot is null)
        {
            return;
        }

        if (snapshot.Phase == ReminderPhase.Paused)
        {
            Phase = ReminderPhase.Paused;
            Remaining = ClampRemaining(
                snapshot.Remaining,
                configuration.WorkDuration);
            return;
        }

        var inactiveDuration = resumedAt - snapshot.SavedAt;
        if (inactiveDuration < TimeSpan.Zero)
        {
            inactiveDuration = TimeSpan.Zero;
        }

        if (inactiveDuration >= configuration.StandingDuration)
        {
            return;
        }

        switch (snapshot.Phase)
        {
            case ReminderPhase.Working:
                Remaining = ClampRemaining(
                    snapshot.Remaining,
                    configuration.WorkDuration);
                break;

            case ReminderPhase.Standing:
                var resumedRemaining = snapshot.Remaining - inactiveDuration;
                if (resumedRemaining <= TimeSpan.Zero)
                {
                    return;
                }

                Phase = ReminderPhase.Standing;
                Remaining = ClampRemaining(
                    resumedRemaining,
                    configuration.StandingDuration);
                break;

            case ReminderPhase.Paused:
                break;
        }
    }

    public ReminderConfiguration Configuration { get; private set; }

    public ReminderPhase Phase { get; private set; }

    public TimeSpan Remaining { get; private set; }

    public int RoundedRemainingSeconds =>
        Math.Max(0, (int)Math.Ceiling(Remaining.TotalSeconds));

    public ReminderTransition Advance(TimeSpan elapsed)
    {
        if (elapsed <= TimeSpan.Zero || Phase == ReminderPhase.Paused)
        {
            return ReminderTransition.None;
        }

        Remaining = Remaining > elapsed
            ? Remaining - elapsed
            : TimeSpan.Zero;

        if (Remaining > TimeSpan.Zero)
        {
            return ReminderTransition.None;
        }

        if (Phase == ReminderPhase.Working)
        {
            Phase = ReminderPhase.Standing;
            Remaining = Configuration.StandingDuration;
            return ReminderTransition.StandingStarted;
        }

        Phase = ReminderPhase.Working;
        Remaining = Configuration.WorkDuration;
        return ReminderTransition.StandingCompleted;
    }

    public ReminderTransition BeginStandingNow()
    {
        if (Phase != ReminderPhase.Working)
        {
            return ReminderTransition.None;
        }

        Phase = ReminderPhase.Standing;
        Remaining = Configuration.StandingDuration;
        return ReminderTransition.StandingStarted;
    }

    public ReminderTransition EndStandingEarly()
    {
        if (Phase != ReminderPhase.Standing)
        {
            return ReminderTransition.None;
        }

        Phase = ReminderPhase.Working;
        Remaining = Configuration.WorkDuration;
        return ReminderTransition.StandingEndedEarly;
    }

    public ReminderTransition PauseWork()
    {
        if (Phase != ReminderPhase.Working)
        {
            return ReminderTransition.None;
        }

        Phase = ReminderPhase.Paused;
        return ReminderTransition.WorkPaused;
    }

    public ReminderTransition ResumeWork()
    {
        if (Phase != ReminderPhase.Paused)
        {
            return ReminderTransition.None;
        }

        Phase = ReminderPhase.Working;
        return ReminderTransition.WorkResumed;
    }

    public ReminderTransition ApplyConfiguration(
        ReminderConfiguration newConfiguration)
    {
        if (Phase != ReminderPhase.Working)
        {
            return ReminderTransition.None;
        }

        var elapsedWork = Configuration.WorkDuration - Remaining;
        if (elapsedWork < TimeSpan.Zero)
        {
            elapsedWork = TimeSpan.Zero;
        }

        Configuration = newConfiguration;
        var updatedRemaining = newConfiguration.WorkDuration - elapsedWork;

        if (updatedRemaining <= TimeSpan.Zero)
        {
            Phase = ReminderPhase.Standing;
            Remaining = newConfiguration.StandingDuration;
            return ReminderTransition.StandingStarted;
        }

        Remaining = updatedRemaining;
        return ReminderTransition.None;
    }

    public void ResetWorkCycle()
    {
        Phase = ReminderPhase.Working;
        Remaining = Configuration.WorkDuration;
    }

    public ReminderSnapshot CreateSnapshot(DateTimeOffset savedAt) =>
        new(Phase, Remaining, savedAt);

    private static TimeSpan ClampRemaining(
        TimeSpan value,
        TimeSpan maximum)
    {
        if (value <= TimeSpan.Zero)
        {
            return TimeSpan.FromSeconds(1);
        }

        return value > maximum ? maximum : value;
    }
}
