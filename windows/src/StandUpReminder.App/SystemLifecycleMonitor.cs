using Microsoft.Win32;

namespace StandUpReminder.App;

internal sealed class SystemLifecycleMonitor : IDisposable
{
    public event Action<string, bool>? ActivityChanged;

    public event Action? ScreensChanged;

    public void Start()
    {
        SystemEvents.SessionSwitch += OnSessionSwitch;
        SystemEvents.PowerModeChanged += OnPowerModeChanged;
        SystemEvents.DisplaySettingsChanged += OnDisplaySettingsChanged;
    }

    public void Dispose()
    {
        SystemEvents.SessionSwitch -= OnSessionSwitch;
        SystemEvents.PowerModeChanged -= OnPowerModeChanged;
        SystemEvents.DisplaySettingsChanged -= OnDisplaySettingsChanged;
    }

    private void OnSessionSwitch(object sender, SessionSwitchEventArgs e)
    {
        switch (e.Reason)
        {
            case SessionSwitchReason.SessionLock:
                ActivityChanged?.Invoke("session", false);
                break;
            case SessionSwitchReason.SessionUnlock:
                ActivityChanged?.Invoke("session", true);
                break;
        }
    }

    private void OnPowerModeChanged(object sender, PowerModeChangedEventArgs e)
    {
        switch (e.Mode)
        {
            case PowerModes.Suspend:
                ActivityChanged?.Invoke("power", false);
                break;
            case PowerModes.Resume:
                ActivityChanged?.Invoke("power", true);
                break;
        }
    }

    private void OnDisplaySettingsChanged(object? sender, EventArgs e) =>
        ScreensChanged?.Invoke();
}
