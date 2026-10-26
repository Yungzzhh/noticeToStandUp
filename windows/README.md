# 站立提醒 Windows 版

Windows 版与 macOS 版共享同一套行为合同，但使用 Windows 原生的 .NET 8、WPF、
系统托盘、注册表登录启动和系统生命周期事件实现。

## 功能

- 默认工作 60 分钟，强制站立休息 5 分钟。
- 可分别设置工作时长与休息时长。
- 支持暂停和继续工作计时，暂停状态跨重启保留。
- 每块显示器显示独立的全屏置顶遮罩，主倒计时位于屏幕正中间。
- 长按 3 秒提前结束本次休息，随后开始完整工作计时，应用不会退出。
- 系统托盘显示倒计时、今日完整休息次数、版本与更新摘要。
- 支持登录时自动启动、锁屏/休眠恢复和单实例运行。
- 配置与状态保存在 `%LocalAppData%\StandUpReminder`。

## 构建

需要 Windows 10/11 和 .NET 8 SDK。在 PowerShell 中运行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\scripts\publish.ps1
```

默认生成 x64 单文件应用：

```text
dist\win-x64-single\StandUpReminder.exe
```

生成 ARM64 版本：

```powershell
.\windows\scripts\publish.ps1 -Runtime win-arm64
```

ARM64 产物位于 `dist\win-arm64-single\StandUpReminder.exe`。

## 强制提醒的边界

应用运行期间，休息窗口无法通过普通关闭、`Esc` 或 `Alt+F4` 跳过。但普通 Windows
应用无法阻止任务管理器结束进程、注销、关机或系统重启。
