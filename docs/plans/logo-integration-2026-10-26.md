# Logo 接入与 GitHub 上传

## 授权与范围

用户要求将已选 Logo 接入应用后上传 GitHub。延续本次 Logo 直接设计授权，按照测试、实现、验证、审查、提交的顺序执行。现有 `dev-*` 技能在当前环境不可用，不伪称已运行。

初始本地仓库无提交和远端。用户已选择新建公开仓库 `Yungzzhh/noticeToStandUp`，授权上传完整项目。

## 任务

- [x] 检查当前工程、资源路径和 Git 状态。
- [x] 添加图标接入回归检查并确认初始失败：4 项检查中 3 项缺少资源报错、1 项因 Windows 工程未声明图标失败。
- [x] 接入 macOS App 图标、菜单栏图标和 Windows EXE、托盘图标；4 项图标检查已转为通过。
- [x] 运行测试、构建、资源及签名验证，审查待提交内容；见 `docs/changes/feat/main-5.md`。
- [x] 确认 GitHub 目标：新建公开仓库 `Yungzzhh/noticeToStandUp`。
- [x] 创建公开远端仓库：https://github.com/Yungzzhh/noticeToStandUp 。
- [x] 提交、推送并从远端回读确认：应用提交 `03c4c0c91efd743141c8273f6b6c989b96d6d2f6` 已推送至 `main`；通过公开 GitHub API 回读确认分支提交一致、全部 64 个文件 blob SHA 一致。

## 验证边界

macOS 使用当前主机验证；Windows 的交叉编译结果不等于真实系统托盘与多屏人工验收。不启动应用以免改变用户当前计时状态。
