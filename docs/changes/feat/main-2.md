---
id: main-2
type: feat
scope: configurable-reminder-durations
related_files:
  - Sources/ReminderCore/ReminderEngine.swift
  - Sources/StandUpReminder/AppDelegate.swift
  - Sources/StandUpReminder/BreakOverlay.swift
  - Sources/StandUpReminder/StateStore.swift
  - Sources/StandUpReminder/StatusMenuController.swift
  - Sources/StandUpReminder/TimerSettingsDialog.swift
  - Tests/ReminderCoreTests/ReminderEngineTests.swift
  - Tests/ReminderCoreTests/StateStoreTests.swift
verification:
  - swift test
  - swift build
  - bash scripts/build-app.sh
risk: medium
rollback: 恢复固定 ReminderConfiguration.standard 并移除计时设置入口
---

# 背景摘要

固定的 60 分钟工作和 5 分钟休息不适合所有工作节奏。新增独立的工作时长与
休息时长设置，同时保证设置不能成为绕过强制休息遮罩的入口。

# 行为变化

- 菜单栏新增“计时设置…”。
- 工作时长支持 15、25、30、45、50、60、75、90 和 120 分钟。
- 休息时长支持 1、3、5、10、15 和 20 分钟。
- 保存新设置时保留本轮已经工作的时长。
- 若新工作时长小于或等于已工作时长，立即进入按新休息时长执行的休息阶段。
- 站立休息期间禁用设置入口；状态机也拒绝休息阶段的配置修改。
- 配置以版本化 JSON 写入 `UserDefaults`，缺失、损坏或越界时回退默认值。
- 菜单、遮罩、通知、锁屏恢复阈值和关于文案统一读取当前配置。

# 边界与失败场景

- 设置弹窗打开期间仍继续计时；如果此时进入休息，弹窗返回的修改会被拒绝。
- 保存相同配置不会重置或改变当前倒计时。
- 设置只提供经过约束的预设时长，不接受任意文本，避免无效或过激配置。
- 调整休息时长不会缩短已经开始的强制休息，因为休息阶段不能保存配置。

# 验证命令

```bash
swift test
swift build
bash scripts/build-app.sh
```

# 风险与回滚

主要风险是配置变更与当前周期剩余时间不一致。状态机通过“已工作时长”重新计算
剩余时间，并对休息阶段拒绝变更。回滚时恢复固定标准配置并移除设置菜单即可。
