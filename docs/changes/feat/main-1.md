---
id: main-1
type: feat
scope: macos-stand-up-reminder
related_files:
  - Package.swift
  - Sources/ReminderCore/ReminderEngine.swift
  - Sources/StandUpReminder/AppDelegate.swift
  - Sources/StandUpReminder/BreakOverlay.swift
  - Sources/StandUpReminder/StatusMenuController.swift
  - Sources/StandUpReminder/StateStore.swift
  - Tests/ReminderCoreTests/ReminderEngineTests.swift
  - scripts/build-app.sh
verification:
  - swift test
  - swift build
  - bash scripts/build-app.sh
risk: medium
rollback: 删除本次新增应用文件即可回到空仓库状态
---

# 背景摘要

项目此前为空仓库。新增一个无第三方依赖的原生 macOS 菜单栏应用，目标是减少
连续久坐：每工作 60 分钟后，强制进入 5 分钟站立休息。

# 行为变化

- 菜单栏展示当前阶段与秒级倒计时。
- 工作满 60 分钟后，在所有显示器显示置顶、跨 Space 的全屏遮罩。
- 遮罩持续 5 分钟，不提供普通跳过、延后或关闭入口。
- 用户可以在工作阶段从菜单栏主动提前开始站立休息。
- 锁屏或休眠期间暂停工作累计；离开满 5 分钟后开启新工作周期。
- 保存当前阶段和剩余时间，支持短时退出后的进度恢复。
- 提供系统通知、提示音、每日完成次数和登录启动开关。

# 边界与失败场景

- 普通 macOS 应用无法阻止强制退出、关机或进程终止，不能承诺系统级锁定。
- 遮罩提供长按 3 秒紧急退出，避免在演示、远程控制或其他紧急场景中失控。
- 登录启动依赖应用已被打包、签名并放入“应用程序”文件夹；失败时会显示原因。
- 系统拒绝通知权限时，全屏遮罩和菜单栏计时仍正常工作。
- 显示器热插拔时会重建遮罩窗口，但不会重置休息倒计时。

# 验证命令

```bash
swift test
swift build
bash scripts/build-app.sh
```

# 风险与回滚

主要风险是 `.screenSaver` 层级遮罩对当前工作流影响较强。紧急退出入口和标准
强制退出能力是安全兜底。若需回滚，本仓库此前没有业务文件，删除本次新增文件
即可；用户偏好保存在 `UserDefaults`，不会影响其他应用。
