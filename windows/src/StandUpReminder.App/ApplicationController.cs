using System.Diagnostics;
using System.Media;
using System.Windows;
using System.Windows.Threading;
using StandUpReminder.Core;

namespace StandUpReminder.App;

internal sealed class ApplicationController : IDisposable
{
    private readonly StateStore _stateStore = new();
    private readonly OverlayCoordinator _overlay;
    private readonly TrayIconController _tray;
    private readonly SystemLifecycleMonitor _lifecycle = new();
    private readonly DispatcherTimer _timer;
    private readonly Stopwatch _tickStopwatch = Stopwatch.StartNew();
    private readonly HashSet<string> _inactiveReasons = [];
    private ReminderEngine _engine = new();
    private DateTimeOffset? _inactiveSince;
    private TimeSpan _lastTickElapsed;
    private TimeSpan _lastPersistedElapsed;
    private bool _disposed;

    public ApplicationController()
    {
        _overlay = new OverlayCoordinator(EndStandingEarly);
        _tray = new TrayIconController(
            BeginStandingNow,
            ToggleWorkPause,
            ShowSettings,
            ShowVersion,
            ToggleStartup,
            ConfirmQuit);
        _timer = new DispatcherTimer(
            TimeSpan.FromSeconds(1),
            DispatcherPriority.Normal,
            OnTimerTick,
            Application.Current.Dispatcher);

        _lifecycle.ActivityChanged += OnActivityChanged;
        _lifecycle.ScreensChanged += OnScreensChanged;
    }

    public void Start()
    {
        var configuration = _stateStore.LoadConfiguration();
        _engine = new ReminderEngine(
            configuration,
            _stateStore.LoadSnapshot(),
            DateTimeOffset.Now);
        _lastTickElapsed = _tickStopwatch.Elapsed;
        _lastPersistedElapsed = _lastTickElapsed;
        _lifecycle.Start();
        _timer.Start();
        RestoreVisibleState();
        UpdateTray();
        PersistState();
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        PersistState();
        _timer.Stop();
        _lifecycle.Dispose();
        _overlay.Hide();
        _tray.Dispose();
    }

    private void OnTimerTick(object? sender, EventArgs e)
    {
        var elapsedNow = _tickStopwatch.Elapsed;
        var elapsed = elapsedNow - _lastTickElapsed;
        _lastTickElapsed = elapsedNow;

        if (_inactiveReasons.Count != 0)
        {
            return;
        }

        HandleTransition(_engine.Advance(elapsed));

        if (_engine.Phase == ReminderPhase.Standing)
        {
            _overlay.Update(_engine.Remaining, _engine.Configuration);
        }

        UpdateTray();

        if (elapsedNow - _lastPersistedElapsed >= TimeSpan.FromSeconds(30))
        {
            PersistState();
            _lastPersistedElapsed = elapsedNow;
        }
    }

    private void BeginStandingNow()
    {
        HandleTransition(_engine.BeginStandingNow());
        UpdateTray();
        PersistState();
    }

    private void EndStandingEarly()
    {
        var transition = _engine.EndStandingEarly();
        if (transition == ReminderTransition.None)
        {
            return;
        }

        HandleTransition(transition);
        ResetTickAnchor();
        UpdateTray();
        PersistState();
    }

    private void ToggleWorkPause()
    {
        var elapsedNow = _tickStopwatch.Elapsed;
        ReminderTransition transition;

        switch (_engine.Phase)
        {
            case ReminderPhase.Working:
                HandleTransition(
                    _engine.Advance(elapsedNow - _lastTickElapsed));
                if (_engine.Phase != ReminderPhase.Working)
                {
                    ResetTickAnchor();
                    UpdateTray();
                    PersistState();
                    return;
                }

                transition = _engine.PauseWork();
                break;

            case ReminderPhase.Paused:
                transition = _engine.ResumeWork();
                break;

            case ReminderPhase.Standing:
                transition = ReminderTransition.None;
                break;

            default:
                transition = ReminderTransition.None;
                break;
        }

        if (transition == ReminderTransition.None)
        {
            return;
        }

        HandleTransition(transition);
        ResetTickAnchor();
        UpdateTray();
        PersistState();
    }

    private void ShowSettings()
    {
        if (_engine.Phase != ReminderPhase.Working)
        {
            return;
        }

        var window = new TimerSettingsWindow(_engine.Configuration);
        if (window.ShowDialog() != true ||
            window.Result is null ||
            _engine.Phase != ReminderPhase.Working ||
            window.Result == _engine.Configuration)
        {
            return;
        }

        var transition = _engine.ApplyConfiguration(window.Result);
        _stateStore.SaveConfiguration(window.Result);
        HandleTransition(transition);
        ResetTickAnchor();
        UpdateTray();
        PersistState();
    }

    private static void ShowVersion()
    {
        var summary = string.Join(
            Environment.NewLine,
            AppReleaseInfo.Highlights.Select(item => $"• {item}"));
        MessageBox.Show(
            $"站立提醒 {AppReleaseInfo.DisplayVersion}\n\n本版本更新\n\n{summary}",
            "版本与更新",
            MessageBoxButton.OK,
            MessageBoxImage.Information);
    }

    private void ToggleStartup()
    {
        try
        {
            StartupManager.SetEnabled(!StartupManager.IsEnabled);
        }
        catch (Exception error) when (
            error is UnauthorizedAccessException or InvalidOperationException)
        {
            MessageBox.Show(
                $"无法修改登录启动设置。\n\n{error.Message}",
                "站立提醒",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        }

        UpdateTray();
    }

    private void ConfirmQuit()
    {
        var result = MessageBox.Show(
            "退出后将停止久坐提醒。确定要退出站立提醒应用吗？",
            "退出站立提醒",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning,
            MessageBoxResult.No);
        if (result != MessageBoxResult.Yes)
        {
            return;
        }

        PersistState();
        Application.Current.Shutdown();
    }

    private void HandleTransition(ReminderTransition transition)
    {
        switch (transition)
        {
            case ReminderTransition.None:
                return;

            case ReminderTransition.StandingStarted:
                _overlay.Show(_engine.Remaining, _engine.Configuration);
                SystemSounds.Exclamation.Play();
                _tray.ShowStandingNotification(_engine.Configuration);
                PersistState();
                break;

            case ReminderTransition.StandingCompleted:
                _overlay.Hide();
                _stateStore.RecordCompletion(
                    _engine.CreateSnapshot(DateTimeOffset.Now));
                SystemSounds.Asterisk.Play();
                PersistState();
                break;

            case ReminderTransition.StandingEndedEarly:
                _overlay.Hide();
                PersistState();
                break;

            case ReminderTransition.WorkPaused:
            case ReminderTransition.WorkResumed:
                PersistState();
                break;
        }
    }

    private void OnActivityChanged(string reason, bool isActive)
    {
        Application.Current.Dispatcher.InvokeAsync(() =>
        {
            if (isActive)
            {
                MarkActive(reason);
            }
            else
            {
                MarkInactive(reason);
            }
        });
    }

    private void MarkInactive(string reason)
    {
        if (_inactiveReasons.Count == 0)
        {
            _inactiveSince = DateTimeOffset.Now;
            PersistState();
            _overlay.Hide();
        }

        _inactiveReasons.Add(reason);
    }

    private void MarkActive(string reason)
    {
        _inactiveReasons.Remove(reason);
        if (_inactiveReasons.Count != 0 || _inactiveSince is null)
        {
            return;
        }

        var inactiveDuration = DateTimeOffset.Now - _inactiveSince.Value;
        if (inactiveDuration < TimeSpan.Zero)
        {
            inactiveDuration = TimeSpan.Zero;
        }

        _inactiveSince = null;
        ResetTickAnchor();

        if (_engine.Phase == ReminderPhase.Paused)
        {
            // 用户主动暂停的状态只能由用户主动继续。
        }
        else if (inactiveDuration >= _engine.Configuration.StandingDuration)
        {
            _engine.ResetWorkCycle();
        }
        else if (_engine.Phase == ReminderPhase.Standing)
        {
            HandleTransition(_engine.Advance(inactiveDuration));
        }

        RestoreVisibleState();
        UpdateTray();
        PersistState();
    }

    private void OnScreensChanged()
    {
        Application.Current.Dispatcher.InvokeAsync(_overlay.ScreensChanged);
    }

    private void RestoreVisibleState()
    {
        if (_engine.Phase == ReminderPhase.Standing)
        {
            _overlay.Show(_engine.Remaining, _engine.Configuration);
        }
    }

    private void UpdateTray()
    {
        _tray.Update(
            _engine,
            _stateStore.CompletedCount(
                _engine.CreateSnapshot(DateTimeOffset.Now)),
            StartupManager.IsEnabled);
    }

    private void PersistState()
    {
        _stateStore.SaveSnapshot(
            _engine.CreateSnapshot(DateTimeOffset.Now));
    }

    private void ResetTickAnchor()
    {
        _lastTickElapsed = _tickStopwatch.Elapsed;
    }
}
