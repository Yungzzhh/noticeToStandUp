# 站立提醒品牌图标接入

## 变化

- macOS 应用包通过 `CFBundleIconFile=AppIcon` 使用多尺寸 ICNS，浅色圆角底板承载薄荷绿人形和深绿计时圆环。
- macOS 菜单栏使用同一轮廓的单色 template 图标，提供 18px 和 36px 两种资源，跟随系统主题着色。缺少资源时保留原 SF Symbol 回退。
- macOS 构建脚本将 ICNS 和菜单栏资源复制到 `Contents/Resources`，再签名应用。
- Windows EXE 使用包含 16、24、32、48、64、128、256px 的 ICO。
- Windows 托盘从程序集嵌入资源加载同一 ICO，兼容单文件发布；退出时释放图标对象。
- 保留原始 Logo 设计稿与透明 PNG，不改变计时规则、状态文件或版本号。

## 验证记录

2026-10-26 当前会话实际执行：

- TDD：新增图标检查首次运行得到 3 项资源缺失错误和 1 项工程声明失败；接入后 4 项全部通过。
- `swift test`：28 项通过；链接阶段存在一条旧 ModuleCache 文件缺失警告，未影响测试或 Release 构建。
- `bash scripts/build-app.sh`：Release 构建、Info.plist 校验和 ad-hoc 签名验证通过。
- 使用 AppKit 对构建后的 `.app` 独立读取：`AppIcon` 可载入；菜单栏可载入 18px 与 36px 两种表示；打包资源字节与源码一致。
- `bash -n scripts/build-app.sh`：通过。
- 临时 .NET SDK 8.0.427 执行 Release 核心测试：7 项通过。
- Windows win-x64 self-contained 单文件发布成功。
- 独立解析发布 EXE：存在 RT_ICON 和 RT_GROUP_ICON 资源，且单文件内包含托盘完整 ICO。
- 上传前检查待提交文件，构建缓存、`bin/obj` 和 `dist` 均由现有 `.gitignore` 排除。

## 验证边界

未启动或替换用户正在运行的应用，避免改变工作和休息计时。Windows 的托盘、主题、DPI 和窗口表现尚未进行真实 Windows 人工验收。

本次 GitHub 上传内容为完整源码、图标资源及项目文档，不包含本地构建产物，不创建 Release。
