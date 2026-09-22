# QuietReader

QuietReader 是一个 macOS 菜单栏小说阅读器，支持 TXT 导入、悬浮阅读、自动翻页、逐字高亮和阅读进度记忆。

## 功能

- 导入本地 UTF-8 TXT 小说
- 菜单栏与可拖动悬浮窗阅读
- 播放、暂停、上一页、下一页
- `0.001x` 到 `16x` 的连续倍速调节
- 播放时逐字高亮，速度与倍速同步
- 自动识别章节目录并快速跳转
- 全览窗口：点击任意页后从该位置开始阅读
- 记住当前书籍、章节和阅读位置
- 支持透明度、字号和显示位置调整

## 系统要求

- macOS 13 Ventura 或更高版本
- Apple Silicon Mac（当前构建目标为 arm64）
- Xcode Command Line Tools 或 Xcode

## 构建 macOS 应用

```bash
chmod +x build.sh
./build.sh
open build/MenuReader.app
```

生成 DMG 安装包：

```bash
./build-dmg.sh
open build/QuietReader-1.0.0.dmg
```

首次打开时，把应用拖入 `Applications` 文件夹即可。由于应用未使用 Apple Developer ID 签名，macOS 若提示无法打开，可在“系统设置 → 隐私与安全性”中允许打开。

## 使用

1. 启动应用，点击菜单栏图标并导入 TXT。
2. 选择“居中”显示模式打开悬浮窗。
3. 点击 `▶` 开始自动阅读。
4. 点击倍速数值选择档位，或用 `‹ / ›` 将速度减半或加倍。
5. 点击 `⤢` 打开全览窗口，点击任意页面后从该处继续。
6. 在“设置 → 目录”中按章节跳转。

## Windows

当前版本依赖 macOS 的 AppKit、SwiftUI 和菜单栏 API，不能直接生成 Windows `.exe`。Windows 版本需要使用 Windows 原生 UI 或跨平台框架重新实现；发布页面不会提供一个无法运行的伪 `.exe`。

## 版权与使用

本项目只负责阅读用户拥有或有权使用的本地文件，不提供或分发未经授权的小说内容。

## License

MIT License
