using StandUpReminder.Core;
using Xunit;

namespace StandUpReminder.Core.Tests;

public sealed class ReminderEngineTests
{
    private static readonly ReminderConfiguration Configuration =
        ReminderConfiguration.Standard;

    [Fact(Timeout = 60_000)]
    public async Task WorkCycleStartsStandingAtExactlyOneHour()
    {
        var engine = new ReminderEngine(Configuration);

        Assert.Equal(
            ReminderTransition.None,
            engine.Advance(TimeSpan.FromSeconds(3_599)));
        Assert.Equal(
            ReminderTransition.StandingStarted,
            engine.Advance(TimeSpan.FromSeconds(1)));
        Assert.Equal(ReminderPhase.Standing, engine.Phase);
        Assert.Equal(TimeSpan.FromMinutes(5), engine.Remaining);
        await Task.CompletedTask;
    }

    [Fact(Timeout = 60_000)]
    public async Task StandingCompletionStartsFreshWorkCycle()
    {
        var engine = new ReminderEngine(Configuration);
        engine.BeginStandingNow();

        Assert.Equal(
            ReminderTransition.StandingCompleted,
            engine.Advance(TimeSpan.FromMinutes(5)));
        Assert.Equal(ReminderPhase.Working, engine.Phase);
        Assert.Equal(TimeSpan.FromMinutes(60), engine.Remaining);
        await Task.CompletedTask;
    }

    [Fact(Timeout = 60_000)]
    public async Task EndingStandingEarlyStartsFreshWorkCycle()
    {
        var engine = new ReminderEngine(Configuration);
        engine.BeginStandingNow();
        engine.Advance(TimeSpan.FromMinutes(2));

        Assert.Equal(
            ReminderTransition.StandingEndedEarly,
            engine.EndStandingEarly());
        Assert.Equal(ReminderPhase.Working, engine.Phase);
        Assert.Equal(TimeSpan.FromMinutes(60), engine.Remaining);
        await Task.CompletedTask;
    }

    [Fact(Timeout = 60_000)]
    public async Task PausingWorkFreezesRemainingTime()
    {
        var engine = new ReminderEngine(Configuration);
        engine.Advance(TimeSpan.FromMinutes(20));

        Assert.Equal(ReminderTransition.WorkPaused, engine.PauseWork());
        engine.Advance(TimeSpan.FromHours(4));
        Assert.Equal(ReminderPhase.Paused, engine.Phase);
        Assert.Equal(TimeSpan.FromMinutes(40), engine.Remaining);
        Assert.Equal(ReminderTransition.WorkResumed, engine.ResumeWork());
        await Task.CompletedTask;
    }

    [Fact(Timeout = 60_000)]
    public async Task StandingCannotBePaused()
    {
        var engine = new ReminderEngine(Configuration);
        engine.BeginStandingNow();

        Assert.Equal(ReminderTransition.None, engine.PauseWork());
        Assert.Equal(ReminderPhase.Standing, engine.Phase);
        await Task.CompletedTask;
    }

    [Fact(Timeout = 60_000)]
    public async Task ShorteningWorkDurationPastElapsedStartsStanding()
    {
        var engine = new ReminderEngine(Configuration);
        engine.Advance(TimeSpan.FromMinutes(40));
        var updated = ReminderConfiguration.Create(
            TimeSpan.FromMinutes(30),
            TimeSpan.FromMinutes(3));

        Assert.Equal(
            ReminderTransition.StandingStarted,
            engine.ApplyConfiguration(updated));
        Assert.Equal(TimeSpan.FromMinutes(3), engine.Remaining);
        await Task.CompletedTask;
    }

    [Fact(Timeout = 60_000)]
    public async Task PausedSnapshotSurvivesLongInterruption()
    {
        var savedAt = DateTimeOffset.FromUnixTimeSeconds(1_000);
        var snapshot = new ReminderSnapshot(
            ReminderPhase.Paused,
            TimeSpan.FromMinutes(23),
            savedAt);

        var engine = new ReminderEngine(
            Configuration,
            snapshot,
            savedAt.AddDays(1));

        Assert.Equal(ReminderPhase.Paused, engine.Phase);
        Assert.Equal(TimeSpan.FromMinutes(23), engine.Remaining);
        await Task.CompletedTask;
    }
}
