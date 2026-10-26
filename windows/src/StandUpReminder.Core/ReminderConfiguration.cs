namespace StandUpReminder.Core;

public sealed record ReminderConfiguration(
    TimeSpan WorkDuration,
    TimeSpan StandingDuration)
{
    public static readonly ReminderConfiguration Standard = new(
        TimeSpan.FromMinutes(60),
        TimeSpan.FromMinutes(5));

    public static ReminderConfiguration Create(
        TimeSpan workDuration,
        TimeSpan standingDuration)
    {
        if (workDuration <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(workDuration));
        }

        if (standingDuration <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(standingDuration));
        }

        return new ReminderConfiguration(workDuration, standingDuration);
    }
}
