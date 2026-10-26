using System.Drawing;
using System.Windows.Forms;
using StandUpReminder.Core;

namespace StandUpReminder.App;

internal sealed class TrayIconController : IDisposable
{
    private readonly NotifyIcon _notifyIcon;
    private readonly Icon _appIcon;
    private readonly ToolStripMenuItem _stateItem = new();
    private readonly ToolStripMenuItem _completedItem = new();
    private readonly ToolStripMenuItem _beginStandingItem = new("立即开始站立");
    private readonly ToolStripMenuItem _pauseItem = new("暂停工作计时");
    private readonly ToolStripMenuItem _settingsItem = new("计时设置…");
    private readonly ToolStripMenuItem _startupItem = new("登录时自动启动");

    public TrayIconController(
        Action beginStanding,
        Action togglePause,
        Action showSettings,
        Action showVersion,
        Action toggleStartup,
        Action quit)
    {
        var menu = new ContextMenuStrip();
        _stateItem.Enabled = false;
        _completedItem.Enabled = false;
        _beginStandingItem.Click += (_, _) => beginStanding();
        _pauseItem.Click += (_, _) => togglePause();
        _settingsItem.Click += (_, _) => showSettings();
        _startupItem.Click += (_, _) => toggleStartup();

        var versionItem = new ToolStripMenuItem("版本与更新…");
        versionItem.Click += (_, _) => showVersion();
        var quitItem = new ToolStripMenuItem("退出应用…");
        quitItem.Click += (_, _) => quit();

        menu.Items.AddRange(
        [
            _stateItem,
            _completedItem,
            new ToolStripSeparator(),
            _beginStandingItem,
            _pauseItem,
            new ToolStripSeparator(),
            _settingsItem,
            _startupItem,
            versionItem,
            new ToolStripSeparator(),
            quitItem
        ]);

        using var iconStream = typeof(TrayIconController).Assembly
            .GetManifestResourceStream("StandUpReminder.AppIcon.ico")
            ?? throw new InvalidOperationException("应用缺少托盘图标资源。");
        _appIcon = new Icon(iconStream, SystemInformation.SmallIconSize);

        _notifyIcon = new NotifyIcon
        {
            Icon = _appIcon,
            Text = "站立提醒",
            ContextMenuStrip = menu,
            Visible = true
        };
    }

    public void Update(
        ReminderEngine engine,
        int completedCount,
        bool startupEnabled)
    {
        var time = FormatTime(engine.RoundedRemainingSeconds);
        var standingText = DurationText(engine.Configuration.StandingDuration);

        switch (engine.Phase)
        {
            case ReminderPhase.Working:
                _stateItem.Text = $"距离站立还有 {time}";
                _pauseItem.Text = "暂停工作计时";
                _pauseItem.Enabled = true;
                _beginStandingItem.Enabled = true;
                _settingsItem.Enabled = true;
                SetTooltip($"距离下一次站立还有 {time}");
                break;

            case ReminderPhase.Standing:
                _stateItem.Text = $"正在站立休息：{time}";
                _pauseItem.Text = "暂停工作计时";
                _pauseItem.Enabled = false;
                _beginStandingItem.Enabled = false;
                _settingsItem.Enabled = false;
                SetTooltip($"正在站立休息：{time}");
                break;

            case ReminderPhase.Paused:
                _stateItem.Text = $"工作计时已暂停：{time}";
                _pauseItem.Text = "继续工作计时";
                _pauseItem.Enabled = true;
                _beginStandingItem.Enabled = false;
                _settingsItem.Enabled = false;
                SetTooltip($"工作计时已暂停，剩余 {time}");
                break;
        }

        _beginStandingItem.Text = $"立即开始站立 {standingText}";
        _completedItem.Text = $"今天已完成 {completedCount} 次站立休息";
        _startupItem.Checked = startupEnabled;
    }

    public void ShowStandingNotification(ReminderConfiguration configuration)
    {
        _notifyIcon.ShowBalloonTip(
            5_000,
            "该站起来了",
            $"你已经连续工作 {DurationText(configuration.WorkDuration)}。现在离开座位，活动 {DurationText(configuration.StandingDuration)}。",
            ToolTipIcon.Info);
    }

    public void Dispose()
    {
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _appIcon.Dispose();
    }

    private void SetTooltip(string text)
    {
        _notifyIcon.Text = text.Length <= 63 ? text : text[..63];
    }

    private static string FormatTime(int seconds) =>
        $"{seconds / 60:00}:{seconds % 60:00}";

    private static string DurationText(TimeSpan duration) =>
        $"{Math.Max(1, (int)Math.Round(duration.TotalMinutes))} 分钟";
}
