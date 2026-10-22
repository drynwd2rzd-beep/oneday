# 一天 OneDay · iOS 原生版

由网页版 OneDay v0.6 完全重写的 SwiftUI 原生 iOS 应用。

- **液态玻璃**：iOS 26 原生 Liquid Glass（标签栏、导航栏、按钮、卡片、弹出面板）；
  「我的 → 显示偏好 → 界面风格」可切换为原版的「经典柔和 / 经典平面」。
- **通知系统**：早晨计划、晚间未完成、记录提醒、事项定时提醒；通知中可直接「完成」或「10 分钟后提醒」；图标角标显示未完成数。
- **数据**：全部保存在本机（Application Support），照片以文件保存；导入/导出与网页版 JSON 备份互相兼容。
- 最低系统 iOS 17；在 iOS 26 上获得完整液态玻璃效果。

## 构建 ipa（不需要 Mac）

1. 把这个文件夹推送到一个 GitHub 仓库的 `main` 分支。
2. GitHub 会自动运行 `.github/workflows/build-ipa.yml`（macOS 26 虚拟机 + Xcode 26）。
3. 在仓库的 **Actions → 最新一次运行 → Artifacts** 下载：
   - `OneDay-unsigned-ipa`：未签名的 ipa；
   - `screenshots-and-logs`：模拟器里各页面的截图和编译日志。

也可以在 Actions 页面点 **Run workflow** 手动运行。

## 安装到 iPhone

ipa 未签名，需要用以下任一工具签名安装：

- **Sideloadly / AltStore**：用免费 Apple ID 签名（7 天有效，需定期重签）。
- **TrollStore**（支持的系统版本）：可直接安装，永久有效。
- **付费开发者账号**：用自己的证书和描述文件签名。

## 在 Mac 上开发

```sh
brew install xcodegen
xcodegen generate
open OneDay.xcodeproj
```

## 目录

- `OneDay/Model` 数据模型（兼容网页版 JSON）、日期工具、文案
- `OneDay/Services` 存储、照片、通知、全局状态
- `OneDay/Design` 主题色、液态玻璃/经典样式、背景
- `OneDay/Views` 今天 / 事项 / 计划 / 回顾 / 我的 及各设置面板
- `web-original` 原网页版源码（仅作参考）
