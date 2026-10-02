# Simple Mirror · 简单镜子

![Platform](https://img.shields.io/badge/Platform-HarmonyOS_26-blue) ![API](https://img.shields.io/badge/API-26-green) ![Language](https://img.shields.io/badge/Language-ArkTS-orange) ![License](https://img.shields.io/badge/License-MIT-lightgrey)

简体中文 | [English](#english) | [更新记录](./CHANGELOG.md)

---

## 简介

简单镜子是一个开源的鸿蒙镜子应用，把手机或平板的前置摄像头变成一面随手可用的镜子。仅申请相机权限，无广告、无跟踪、无多余功能。

## 功能特性

- 🪞 实时镜像预览，可切换「照镜子 / 他人视角」
- 🔍 相机变焦滑杆（光学变焦，范围随设备能力自适应）
- 🤏 双指捏合数字放大（1x–5x），放大后单指拖动查看，双击复位
- ⏸️ 一键定格画面，定格照片可保存到系统图库
- 📱 手机 / 平板通用，横竖屏自适应（含相机方向与镜像的显示层补偿）

## 环境要求

- [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 26.0.0 及以上（内置 HarmonyOS SDK，API 26）
- 运行 HarmonyOS 26 的手机或平板
- 华为账号（用于生成调试签名）

## 构建运行

```bash
git clone https://github.com/jimmy-smh/simple-mirror-harmonyos.git
```

1. 用 DevEco Studio 打开项目根目录，等待 Sync 完成；
2. **文件 → Project Structure → Signing Configs**，勾选 *Automatically generate signature* 并登录华为账号；
3. 连接设备，点击 **Run** 运行。

## 项目结构

```text
entry/src/main/ets/pages/Index.ets    # 全部业务逻辑：相机、预览、定格、缩放、横竖屏适配
entry/src/main/module.json5           # 权限（相机）、设备类型、方向
AppScope/app.json5                    # 包名 com.jimmysmh.simplemirror
```

## 说明

- 应用 `compatibleSdkVersion` 为 26.0.0，仅可安装于 HarmonyOS 26 及以上设备；
- 部分平板相机 HAL 的预览方向补偿不随窗口旋转，应用在显示层按屏幕旋转档位做了回转与镜像修正。

## 许可证

[MIT](./LICENSE) © 2026 Jimmy-SM_Huang

---

<a id="english"></a>

## English

### Introduction

Simple Mirror is an open-source mirror app for HarmonyOS that turns the front camera of your phone or tablet into an always-ready mirror. It only requests the camera permission — no ads, no tracking, no clutter.

### Features

- 🪞 Live mirror preview with a toggle between "mirror" and "as others see you" modes
- 🔍 Camera zoom slider (optical zoom, range adapts to device capability)
- 🤏 Pinch-to-zoom (1x–5x) with one-finger pan while zoomed; double-tap to reset
- ⏸️ One-tap freeze-frame; save frozen shots to the system gallery
- 📱 Works on phones and tablets with adaptive portrait/landscape layout (including display-level camera orientation & mirror compensation)

### Requirements

- [DevEco Studio](https://developer.huawei.com/consumer/en/deveco-studio/) 26.0.0 or later (bundled HarmonyOS SDK, API 26)
- A phone or tablet running HarmonyOS 26
- A HUAWEI account (for auto-generated debug signing)

### Build & Run

```bash
git clone https://github.com/jimmy-smh/simple-mirror-harmonyos.git
```

1. Open the project root in DevEco Studio and wait for Sync to finish;
2. **File → Project Structure → Signing Configs**, enable *Automatically generate signature* and sign in with your HUAWEI account;
3. Connect a device and click **Run**.

### Project Structure

```text
entry/src/main/ets/pages/Index.ets    # All logic: camera, preview, freeze-frame, zoom, orientation handling
entry/src/main/module.json5           # Permissions (camera), device types, orientation
AppScope/app.json5                    # Bundle name com.jimmysmh.simplemirror
```

### Notes

- `compatibleSdkVersion` is 26.0.0, so the app installs only on devices running HarmonyOS 26 or later;
- On some tablets the camera HAL does not rotate the preview with the window, so the app compensates at the display layer based on the screen rotation state.

### License

[MIT](./LICENSE) © 2026 Jimmy-SM_Huang
