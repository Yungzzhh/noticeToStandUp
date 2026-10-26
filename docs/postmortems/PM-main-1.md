---
id: PM-main-1
branch: main
scope: break-overlay-layout
severity: low
status: resolved
related_files:
  - Sources/StandUpReminder/BreakOverlay.swift
verification:
  - swift test
  - swift build
  - bash scripts/build-app.sh
---

# 事件摘要

强制休息遮罩使用了覆盖整块屏幕的 `NSPanel`，但标题、倒计时、活动建议、
下一轮说明和紧急退出都放在同一个纵向容器中。容器整体居中时，主标题和倒计时
会被下方内容推到屏幕几何中心上方，造成“遮罩不在正中间”的视觉问题。

# 根因

窗口尺寸和多显示器坐标没有错误。根因是布局把主视觉内容与底部辅助内容作为同一
个整体参与居中计算，并依赖 `NSHostingController` 的隐式尺寸传播，没有明确表达
“主视觉中心必须等于每块屏幕中心”的约束。

# 修复

- `NSHostingController.view` 显式设置为当前 `NSScreen` 的尺寸并随窗口缩放。
- 图标、标题、倒计时和进度条拆成 `centralContent`，占满窗口并中心对齐。
- 活动建议、下一轮说明和紧急退出拆成 `bottomContent`，独立固定在屏幕底部。
- 保留 `screen.frame`，确保菜单栏和 Dock 区域仍属于强制遮罩范围。

# 防复发

- `triggers.yml` 增加遮罩主视觉偏移检查。
- 后续增加遮罩内容时，辅助信息不得加入 `centralContent` 的尺寸计算。
- 发布前在主屏和外接屏分别检查倒计时是否处于各自屏幕中心。
