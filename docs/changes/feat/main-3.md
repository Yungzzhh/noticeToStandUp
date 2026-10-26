---
id: main-3
type: feat
scope: pause-and-release-information
related_files:
  - Resources/Info.plist
  - Sources/ReminderCore/ReminderEngine.swift
  - Sources/StandUpReminder/AppDelegate.swift
  - Sources/StandUpReminder/StatusMenuController.swift
  - Sources/StandUpReminder/VersionInfoDialog.swift
  - Tests/ReminderCoreTests/ReminderEngineTests.swift
  - Tests/ReminderCoreTests/ReleaseInfoTests.swift
  - Tests/ReminderCoreTests/StateStoreTests.swift
  - scripts/build-app.sh
verification:
  - swift test
  - swift build
  - bash scripts/build-app.sh
risk: medium
rollback: 移除 paused 状态与版本菜单，并恢复 1.0.0 Build 1
---

# 背景摘要

用户需要在临时会议或其他不应累计久坐时间的场景中主动暂停工作倒计时，
同时需要在应用内确认正在使用的版本并查看本版本更新内容。

# 行为变化

- 菜单栏新增“暂停工作计时”和“继续工作计时”。
- 暂停只允许发生在工作阶段；休息期间按钮禁用，状态机也拒绝暂停请求。
- 暂停期间不扣减剩余时间，恢复后从原剩余时间继续。
- 暂停状态写入现有状态快照，应用重启、锁屏或休眠后仍保持暂停。
- 暂停时禁用立即休息和计时设置，避免同时发生含义冲突的状态迁移。
- 菜单栏新增“版本与更新…”，使用 macOS 原生 About 面板展示版本、Build
  和更新摘要。
- 版本升级为 `1.1.0`，Build 升级为 `2`。
- 更新摘要存放在 `Info.plist` 的 `SURReleaseHighlights`，运行时从 App 包读取。

# 边界与失败场景

- 重复暂停、重复继续或休息阶段暂停均为无操作。
- 点击暂停时先结算上次计时刷新以来的实际经过时间，避免漏记不足一秒的工作时间。
- 暂停状态不会因为离开电脑超过休息时长而自动解除，只能由用户主动继续。
- App 包缺少更新摘要时，版本面板显示“暂无更新说明”。
- 构建脚本校验源码与 App 包内版本一致，并拒绝缺少更新摘要的产物。

# 验证命令

```bash
swift test
swift build
bash scripts/build-app.sh
```

# 风险与回滚

主要风险是暂停状态在重启或系统唤醒后被错误重置。状态恢复优先识别 `.paused`，
生命周期恢复逻辑也不会对暂停状态应用“离开满休息时长”的重置规则。回滚时移除
暂停状态及菜单入口，并恢复上一版本的 Bundle 版本号。
