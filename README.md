# 一天 · One Day PWA

这是可安装到 iPhone/iPad 主屏幕的 PWA 版本。

## 文件
- index.html：主应用
- manifest.json：PWA 安装信息
- service-worker.js：离线缓存
- icon.svg：应用图标

## 重要：iPhone 不能直接从“本地文件”把 PWA 完整安装
PWA 的 Service Worker 通常需要 HTTPS 网站环境。

最简单方式是把这个文件夹部署到一个 HTTPS 静态网站，再用 iPhone Safari 打开。

Safari：
1. 打开网站
2. 点击分享
3. 选择“添加到主屏幕”
4. 桌面会出现“一天”
5. 以后像 App 一样全屏打开

数据默认保存在该设备浏览器中，可通过“数据与备份”导出 JSON。
