# 更新记录 | Changelog

## v1.0.2（2026-10-02）

### 修复 | Fixes

- **退后台后画面冻结**：应用退到后台再回到前台后，预览画面不再更新，需从最近任务清理后重启才恢复。现通过自定义 `XComponentController` 监听 surface 的创建/销毁，surface 销毁时释放相机、重建时自动在新 surface 上重建会话；并以页面前后台生命周期（`onPageShow`/`onPageHide`）兜底，同时保证后台不占用相机。
- **释放健壮性**：相机释放改为幂等（先摘引用再逐个释放，并补上此前遗漏的 `PhotoOutput`），页面隐藏、surface 销毁、组件卸载并发触发也不会重复释放或泄漏；初始化期间 surface 被重建时自动重试。
- **分层图标**：应用图标改为分层图标（layered icon），消除 IDE 关于启动体验的警告。

- **Frozen preview after backgrounding**: returning to the foreground no longer shows a stale frame. A custom `XComponentController` listens to surface creation/destruction, releasing the camera when the surface dies and rebuilding the session on the new one; page show/hide lifecycle acts as a fallback, and the camera is never held in the background.
- **Release robustness**: camera release is now idempotent (detach-then-release, including the previously missed `PhotoOutput`), safe against concurrent triggers; initialization retries automatically if the surface is recreated mid-init.
- **Layered app icon** adopted, resolving the IDE startup-experience warning.

## v1.0.1（2026-10-02）

### 修复 | Fixes

- **画面比例失真**：预览 surface 宽高比改为对齐相机流真实比例（竖屏 3:4 / 横屏 4:3），再以 Cover 方式等比铺满屏幕、裁掉溢出，消除竖屏高度拉长、横屏高度压扁的问题。
- **横屏定格照片翻转**：预览流与拍照流的镜像翻转统一移至屏幕坐标系处理（两者镜像极性相反），修正横屏下定格照片潜在的上下翻转。
- **放大后拖动边界**：捏合放大后的单指拖动范围改按真实覆盖尺寸计算，边界更准确。

- **Aspect-ratio distortion**: the preview surface now matches the camera stream's native ratio and fills the screen with uniform scale + crop, fixing the stretched (portrait) / squashed (landscape) image.
- **Frozen-photo flip in landscape**: mirror flipping for preview and photo streams is unified into screen space with opposite polarity, fixing a latent upside-down flip.
- **Pan bounds while zoomed** are now computed from the actual cover footprint.

## v1.0.0（2026-10-01）

### 初始版本 | Initial Release

- 前置摄像头实时镜像预览，支持「照镜子 / 他人视角」切换
- 相机光学变焦滑杆，范围随设备能力自适应
- 一键定格画面，定格照片可保存到系统图库（SaveButton 安全控件，免存储权限）
- 双指捏合数字放大（1x–5x）、放大后单指拖动查看、双击复位
- 手机 / 平板通用，横竖屏自适应（含相机方向与镜像的显示层补偿）
- 应用名「简单镜子 / Simple Mirror」，包名 `com.jimmysmh.simplemirror`，中英双语资源

- Live front-camera mirror preview with mirror toggle
- Optical zoom slider adapting to device capability
- One-tap freeze-frame with gallery saving via SaveButton (no storage permission needed)
- Pinch-to-zoom (1x–5x) with one-finger pan and double-tap reset
- Adaptive portrait/landscape layout on phones and tablets (display-level camera orientation & mirror compensation)
- App name "Simple Mirror", bundle `com.jimmysmh.simplemirror`, bilingual (zh/en) resources
