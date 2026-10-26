---
id: PM-main-3
branch: main
scope: release-build-script
severity: low
status: resolved
related_files:
  - scripts/build-app.sh
verification:
  - bash scripts/build-app.sh
  - codesign --verify --deep --strict dist/StandUpReminder.app
---

# 事件摘要

Release 二进制、App 组装和签名均已成功，但构建脚本在输出中文版本信息时触发
`unbound variable`，最终返回非零退出码，导致完整发布门禁失败。

# 根因

脚本启用了 `set -u`。版本变量使用裸 `$BUNDLE_VERSION` 和 `$BUNDLE_BUILD`，
后面直接连接全角括号。当前 Shell 对变量边界的解析把相邻字符带入变量引用，
因而尝试读取不存在的变量。

# 修复

- 将输出改为 `${BUNDLE_VERSION}` 和 `${BUNDLE_BUILD}`，显式限定变量边界。
- 保留 `set -u`，继续让未定义变量成为构建失败，而不是降低脚本检查强度。

# 防复发

- `set -u` 脚本中的变量展开统一使用花括号。
- 变量与中文或全角标点相邻时禁止使用裸变量形式。
- Release 验收必须检查脚本退出码，不能只检查 App 是否已生成。
