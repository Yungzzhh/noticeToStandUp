using System.Windows.Forms;
using StandUpReminder.Core;

namespace StandUpReminder.App;

internal sealed class OverlayCoordinator
{
    private readonly Action _endStandingEarly;
    private readonly List<OverlayWindow> _windows = [];
    private bool _isVisible;

    public OverlayCoordinator(Action endStandingEarly)
    {
        _endStandingEarly = endStandingEarly;
    }

    public void Show(
        TimeSpan remaining,
        ReminderConfiguration configuration)
    {
        if (!_isVisible)
        {
            _isVisible = true;
            Rebuild();
        }

        Update(remaining, configuration);
    }

    public void Update(
        TimeSpan remaining,
        ReminderConfiguration configuration)
    {
        foreach (var window in _windows)
        {
            window.Update(remaining, configuration);
        }
    }

    public void Hide()
    {
        _isVisible = false;
        foreach (var window in _windows)
        {
            window.CloseOverlay();
        }

        _windows.Clear();
    }

    public void ScreensChanged()
    {
        if (_isVisible)
        {
            Rebuild();
        }
    }

    private void Rebuild()
    {
        foreach (var window in _windows)
        {
            window.CloseOverlay();
        }

        _windows.Clear();

        foreach (var screen in Screen.AllScreens)
        {
            var window = new OverlayWindow(screen, _endStandingEarly);
            _windows.Add(window);
            window.Show();
        }
    }
}
