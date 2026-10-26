# 站立提醒 Logo 设计

- 授权：用户允许本次直接设计，指定使用 `custom-responses-image-generation`。
- 范围：生成独立 Logo 设计稿，不修改应用资源、菜单栏实现或构建配置。
- 方向：站立伸展人形与未闭合计时圆环；薄荷绿、深墨色；简洁几何造型。
- 交付：`docs/changes/logo-2026-10-26/standup-logo.png`，1024 × 1024 PNG。

## 执行状态

- [x] 确定设计方向与输出位置。
- [x] 使用指定技能生成图像；单次 API 请求成功返回。
- [x] 回读文件，检查尺寸并预览视觉效果。

## 交付与验证

- `docs/changes/logo-2026-10-26/standup-logo.png`：1024 × 1024 RGBA PNG，透明背景。
- `docs/changes/logo-2026-10-26/standup-logo-preview.png`：1024 × 1024 RGB PNG，浅色背景预览。
- `docs/changes/logo-2026-10-26/standup-logo-generated-original.png`：保留 API 返回的 1254 × 1254 原图。
- 后处理：清理透明通道低透明度杂点，将人形与圆环统一为指定纯色，并缩放到交付尺寸；未再次调用生成接口。
- 验证：通过 Pillow 独立回读格式、尺寸及透明通道；已目视检查浅色背景预览。
- 范围说明：本次仅交付位图设计稿，尚未验证或接入 macOS 菜单栏及 Windows 托盘小尺寸显示。

## 生成提示词

Create one finished, original logo symbol for a native desktop wellness app called Stand Up Reminder, which gently reminds desk workers to stand up and move. Deliver a single centered symbol, not a presentation board or mockup. Visual idea: a graceful upright human stretching upward, formed from a small circular head and bold, smooth, carefully balanced geometric limbs; integrate this figure into an open circular timer arc. The open arc should subtly suggest time passing and an upward release into movement. The human must read as standing tall, with arms lifted into a gentle open V and two grounded legs; avoid a running pose. Create a distinctive, cohesive silhouette with generous negative space and excellent legibility when reduced to 24 pixels. Use mint green #69DFC0 for the main figure and muted deep forest teal #17685C for the timer arc, with an optional tiny warm cream accent only if necessary. Flat vector-like shapes, rounded terminals, consistent visual weight, sophisticated calm premium macOS utility aesthetic. Composition: symbol occupies approximately 72 percent of the square canvas, perfectly optically centered, generous even padding. Fully transparent background. No lettering, no words, no numbers, no gradients, no 3D, no shadows, no texture, no outline box, no app tile, no watermark, no extra variants. Output high-quality 1024 by 1024 transparent PNG.
