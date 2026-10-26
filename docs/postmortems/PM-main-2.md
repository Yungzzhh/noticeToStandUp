---
id: PM-main-2
branch: main
scope: early-standing-end
severity: medium
status: resolved
related_files:
  - Sources/ReminderCore/ReminderEngine.swift
  - Sources/StandUpReminder/AppDelegate.swift
  - Sources/StandUpReminder/BreakOverlay.swift
  - Tests/ReminderCoreTests/ReminderEngineTests.swift
verification:
  - swift test
  - swift build
  - bash scripts/build-app.sh
---

# 事件摘要

强制休息遮罩底部的长按操作被实现为“紧急退出应用”。用户长按后，
`NSApp.terminate` 直接结束进程，因此遮罩虽然消失，但菜单栏提醒也停止运行，
无法开始下一轮工作计时。

# 根因

遮罩退出与应用退出复用了同一个语义。`BreakOverlayCoordinator` 暴露的闭包名为
`emergencyQuit`，`AppDelegate` 直接将它连接到 `NSApp.terminate`，状态机没有
“提前结束休息”的显式事件，也就无法表达“关闭遮罩但继续运行”的业务行为。

# 修复

- 状态机新增 `endStandingEarly()` 和 `standingEndedEarly` 迁移。
- 休息中提前结束会进入 `working`，剩余时间重置为完整的当前工作时长。
- `AppDelegate` 收到该迁移后只关闭遮罩、刷新菜单并持久化状态，不再退出应用。
- 提前结束不增加每日已完成休息次数；自然完成仍按原逻辑计数。
- 遮罩文案和无障碍提示统一改为“结束本次休息并重新开始工作计时”。

# 防复发

- 状态机测试覆盖休息中提前结束和工作中误调用两个边界。
- `triggers.yml` 规定遮罩内部操作不得直接调用 `NSApp.terminate`。
- 应用退出只保留在菜单栏“退出应用…”及其确认流程中。
