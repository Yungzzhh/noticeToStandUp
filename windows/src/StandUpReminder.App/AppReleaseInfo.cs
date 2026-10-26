using System.Reflection;

namespace StandUpReminder.App;

internal static class AppReleaseInfo
{
    public const string Version = "1.1.0";
    public const string Build = "2";

    public static readonly string[] Highlights =
    [
        "支持暂停与继续工作计时，暂停状态可以跨重启保留。",
        "可以查看版本号、Build 编号和本版本更新摘要。",
        "支持分别设置工作时长和休息时长。",
        "休息倒计时固定显示在每块屏幕正中间。",
        "长按结束休息后重新开始工作计时，不退出应用。"
    ];

    public static string DisplayVersion
    {
        get
        {
            var version = Assembly.GetEntryAssembly()?
                .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
                .InformationalVersion
                .Split('+')[0] ?? Version;
            return $"v{version} (Build {Build})";
        }
    }
}
