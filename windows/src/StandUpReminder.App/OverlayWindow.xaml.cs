using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Threading;
using StandUpReminder.Core;
using Screen = System.Windows.Forms.Screen;

namespace StandUpReminder.App;

public partial class OverlayWindow : Window
{
    private const uint SwpNoActivate = 0x0010;
    private static readonly nint HwndTopmost = new(-1);

    private readonly Screen _screen;
    private readonly Action _endStandingEarly;
    private readonly Stopwatch _longPressStopwatch = new();
    private readonly DispatcherTimer _longPressTimer;
    private bool _allowClose;
    private bool _longPressTriggered;

    public OverlayWindow(Screen screen, Action endStandingEarly)
    {
        InitializeComponent();
        _screen = screen;
        _endStandingEarly = endStandingEarly;
        _longPressTimer = new DispatcherTimer(
            TimeSpan.FromMilliseconds(50),
            DispatcherPriority.Input,
            OnLongPressTick,
            Dispatcher);
        SourceInitialized += OnSourceInitialized;
    }

    public void Update(
        TimeSpan remaining,
        ReminderConfiguration configuration)
    {
        var remainingSeconds = Math.Max(
            0,
            (int)Math.Ceiling(remaining.TotalSeconds));
        RemainingText.Text = $"{remainingSeconds / 60:00}:{remainingSeconds % 60:00}";
        HeadlineText.Text =
            $"现在，站起来活动 {DurationText(configuration.StandingDuration)}";
        NextCycleText.Text =
            $"完成后会自动开始下一轮 {DurationText(configuration.WorkDuration)}工作计时";
        Progress.Value = Math.Clamp(
            (configuration.StandingDuration - remaining).TotalSeconds /
            configuration.StandingDuration.TotalSeconds,
            0,
            1);
    }

    public void CloseOverlay()
    {
        _allowClose = true;
        Close();
    }

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        var bounds = _screen.Bounds;
        var handle = new WindowInteropHelper(this).Handle;
        SetWindowPos(
            handle,
            HwndTopmost,
            bounds.Left,
            bounds.Top,
            bounds.Width,
            bounds.Height,
            SwpNoActivate);
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key is Key.Escape or Key.F4)
        {
            e.Handled = true;
        }
    }

    private void OnClosing(object? sender, CancelEventArgs e)
    {
        e.Cancel = !_allowClose;
    }

    private void OnEndEarlyMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton != MouseButton.Left)
        {
            return;
        }

        _longPressTriggered = false;
        _longPressStopwatch.Restart();
        _longPressTimer.Start();
        EndEarlyControl.CaptureMouse();
        EndEarlyText.Text = "继续按住…";
        e.Handled = true;
    }

    private void OnEndEarlyMouseUp(object sender, MouseButtonEventArgs e) =>
        CancelLongPress();

    private void OnEndEarlyMouseLeave(object sender, MouseEventArgs e)
    {
        if (Mouse.LeftButton != MouseButtonState.Pressed)
        {
            CancelLongPress();
        }
    }

    private void OnEndEarlyLostMouseCapture(object sender, MouseEventArgs e) =>
        CancelLongPress();

    private void OnLongPressTick(object? sender, EventArgs e)
    {
        if (_longPressTriggered || _longPressStopwatch.Elapsed < TimeSpan.FromSeconds(3))
        {
            return;
        }

        _longPressTriggered = true;
        _longPressTimer.Stop();
        _longPressStopwatch.Stop();
        EndEarlyControl.ReleaseMouseCapture();
        _endStandingEarly();
    }

    private void CancelLongPress()
    {
        if (_longPressTriggered)
        {
            return;
        }

        _longPressTimer.Stop();
        _longPressStopwatch.Reset();
        if (EndEarlyControl.IsMouseCaptured)
        {
            EndEarlyControl.ReleaseMouseCapture();
        }

        EndEarlyText.Text = "长按 3 秒结束本次休息";
    }

    private static string DurationText(TimeSpan duration) =>
        $"{Math.Max(1, (int)Math.Round(duration.TotalMinutes))} 分钟";

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetWindowPos(
        nint hWnd,
        nint hWndInsertAfter,
        int x,
        int y,
        int cx,
        int cy,
        uint flags);
}
