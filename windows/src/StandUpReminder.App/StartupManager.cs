using Microsoft.Win32;

namespace StandUpReminder.App;

internal static class StartupManager
{
    private const string RunKey =
        @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "StandUpReminder";

    public static bool IsEnabled
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey);
            return key?.GetValue(ValueName) is string value &&
                string.Equals(value, QuotedExecutablePath(), StringComparison.OrdinalIgnoreCase);
        }
    }

    public static void SetEnabled(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey, writable: true)
            ?? throw new InvalidOperationException("无法打开当前用户的登录启动注册表项。");

        if (enabled)
        {
            key.SetValue(ValueName, QuotedExecutablePath());
        }
        else
        {
            key.DeleteValue(ValueName, throwOnMissingValue: false);
        }
    }

    private static string QuotedExecutablePath()
    {
        var processPath = Environment.ProcessPath
            ?? throw new InvalidOperationException("无法确定应用路径。");
        return $"\"{processPath}\"";
    }
}
