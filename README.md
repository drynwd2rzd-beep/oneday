# 一天 OneDay · iOS 原生版

由网页版 OneDay v0.6 完全重写的 SwiftUI 原生 iOS 应用。

- **液态玻璃**：iOS 26 原生 Liquid Glass；「我的 → 显示偏好」可切换「经典柔和 / 经典平面」。
- **数据**：SQLite 数据库，只写入改动的记录；照片、视频、录音以文件保存；兼容网页版 JSON 备份。
- **撤销**：删除和修改后可在提示中撤销，或摇一摇撤销。事项、计划、记录支持左右滑动操作。
- **隐私**：6 位数字或字母数字密码锁 + 面容 ID，多任务界面自动遮挡；密码只以加盐摘要存在本机钥匙串。
- **备份**：自动备份到你选择的文件夹（推荐 iCloud 云盘），含全部媒体，保留 14 天历史；本机每日快照；完整导出/恢复。
- **记录**：文字、照片、视频、语音、地点与天气（Open-Meteo）；首页「那年今日」。
- **统计**：本周报告（与上周同期对比）、全年热力图、每个事项的连续天数与完成率。
- **通知**：早晨计划、晚间未完成、记录提醒、事项定时提醒（通知中可完成 / 稍后提醒），后台刷新保持排程。
- **工程**：16 个单元测试 + 5 个界面测试在 CI 中运行；MetricKit 本机崩溃诊断；隐私清单。
- 最低系统 iOS 18；在 iOS 26 上获得完整液态玻璃效果。

## 构建 ipa（不需要 Mac）

1. 把这个文件夹推送到一个 GitHub 仓库的 `main` 分支。
2. GitHub 会自动运行 `.github/workflows/build-ipa.yml`（macOS 26 虚拟机 + Xcode 26）。
3. 在仓库的 **Actions → 最新一次运行 → Artifacts** 下载：
   - `OneDay-unsigned-ipa`：未签名的 ipa；
   - `screenshots-and-logs`：模拟器里各页面的截图、编译日志和测试日志。

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
