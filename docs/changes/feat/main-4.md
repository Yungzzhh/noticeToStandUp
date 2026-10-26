---
id: main-4
type: feat
scope: windows-native-application
related_files:
  - windows/StandUpReminder.Windows.sln
  - windows/src/StandUpReminder.Core/ReminderEngine.cs
  - windows/src/StandUpReminder.App/ApplicationController.cs
  - windows/src/StandUpReminder.App/OverlayWindow.xaml
  - windows/src/StandUpReminder.App/TrayIconController.cs
  - windows/tests/StandUpReminder.Core.Tests/ReminderEngineTests.cs
  - windows/scripts/publish.ps1
  - scripts/build-current-platform.sh
  - scripts/build-current-platform.ps1
verification:
  - swift test
  - bash scripts/build-current-platform.sh
  - dotnet test windows/StandUpReminder.Windows.sln --configuration Release
  - powershell -File windows/scripts/publish.ps1
risk: high
rollback: 删除 windows 目录和统一平台构建脚本，不影响现有 macOS 应用
---

# 背景摘要

现有 Swift/AppKit 应用只能在 macOS 运行。Windows 的托盘、多显示器、开机启动、
锁屏休眠和窗口置顶 API 与 macOS 完全不同，不能通过同一二进制在运行时识别平台。
因此在同一仓库新增独立的 Windows 原生实现，并共享同一套产品行为和版本语义。

# 行为变化

- 新增 C#/.NET 8/WPF Windows 解决方案。
- Windows 状态机覆盖工作、休息、暂停、自然完成、提前结束和设置更新。
- 使用 `NotifyIcon` 提供系统托盘倒计时、设置、暂停、版本信息、登录启动和退出。
- 为每块显示器创建独立置顶遮罩；中央倒计时不受底部内容影响。
- 应用清单声明 PerMonitorV2 DPI，遮罩使用各显示器物理边界，支持负坐标副屏。
- 使用长按 3 秒结束休息，应用继续运行并开启完整工作周期。
- 使用 `%LocalAppData%\StandUpReminder` 版本化 JSON 保存配置、状态和完成次数。
- 监听锁屏、解锁、休眠、唤醒与显示器变化事件。
- 使用 HKCU Run 注册表项配置当前用户登录启动，无需管理员权限。
- 使用命名 Mutex 防止出现两个托盘图标和两套计时器。
- 新增 PowerShell 单文件发布脚本，以及识别当前平台的统一 Bash 构建入口。
- WPF 原生运行库嵌入自解压单文件产物，交付时只需复制 `StandUpReminder.exe`。

# 边界与失败场景

- macOS 和 Windows 使用独立 UI 工程，避免用跨平台抽象削弱系统级交互质量。
- Windows 设置和状态文件损坏、缺失或越界时回退默认值，写入失败不终止提醒。
- 休息期间无法修改设置或暂停；提前结束不计入完整休息次数。
- 普通应用无法阻止任务管理器终止进程、注销、关机或系统重启。
- 当前系统原本没有全局 .NET SDK；验证时使用 `/tmp` 内的临时 .NET 8 SDK，已完成
  Windows x64 交叉编译、核心测试和单文件发布，不修改全局开发环境。
- macOS 无法启动 Windows WPF 界面，多屏、托盘、注册表和锁屏休眠仍需在真实
  Windows 10/11 环境做最终人工验收。

# 验证命令

macOS 回归：

```bash
swift test
bash scripts/build-current-platform.sh
```

Windows：

```powershell
dotnet test .\windows\StandUpReminder.Windows.sln --configuration Release
.\windows\scripts\publish.ps1
```

# 风险与回滚

主要风险来自 WPF 多屏 DPI、Win32 置顶窗口、系统事件线程与注册表差异。核心状态机
与平台层分离以降低风险；Windows 需要在真实多屏和不同缩放比例下人工验收。
回滚只需移除 `windows/` 和统一入口，现有 macOS 产物与状态不受影响。
