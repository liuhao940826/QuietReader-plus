# QuietReader

<p align="center">
  <strong>一款面向本地 TXT 文件的 macOS 菜单栏阅读器。</strong><br>
  悬浮阅读 · 自动翻页 · 章节导航 · 进度恢复
</p>

<p align="center">
  中文 · <a href="README.md">English</a>
</p>

---

## 项目简介

QuietReader 是一款原生 macOS 菜单栏阅读器，支持导入本地 UTF-8 TXT 文件。它提供可拖动的悬浮阅读窗，可以覆盖在其他应用上方，同时自动保存书籍、章节和阅读位置。

## 功能亮点

- **悬浮阅读**：可拖动窗口，支持透明度、显示位置和字号调整。
- **自动播放**：支持播放、暂停、上一页、下一页和倍速调节。
- **逐字高亮**：播放时文字按当前速度逐步变为高亮颜色。
- **章节目录**：自动识别常见中文章节标题并快速跳转。
- **全览定位**：浏览分页预览，点击任意段落后从该位置开始阅读。
- **多显示器支持**：可选择内建显示器或外接显示器，避免双屏重复显示。
- **进度恢复**：自动记住当前书籍、页码和字符位置。

## 功能截图

### 菜单栏控制

菜单栏中集中提供阅读、书籍、显示、透明度和显示器设置。

![菜单栏控制](docs/screenshots/menu-bar-floating.png)

### 指定显示器

连接外接显示器时，可以选择只在哪一台屏幕显示悬浮窗。

![显示器选择](docs/screenshots/screen-selection.png)

![外接屏显示](docs/screenshots/external-display.png)

### 播放与逐字高亮

播放时文字会按照当前倍速逐字变为高亮颜色，调整倍速后染色速度也会同步变化。

![逐字高亮](docs/screenshots/word-highlight-playback.png)

### 书库、目录与全览

书库显示当前书籍和阅读进度；目录适合按章节跳转；全览窗口适合精确定位到某一页或段落。

![书库与阅读进度](docs/screenshots/library.png)

![章节目录](docs/screenshots/chapter-directory.png)

![全览与章节定位](docs/screenshots/overview-and-directory.png)

## 下载

前往 [Releases](https://github.com/liuhao940826/QuietReader-plus/releases) 下载最新 macOS 安装包。当前版本提供 `QuietReader-1.0.0.dmg`，面向 Apple Silicon Mac。

> 应用未使用 Apple Developer ID 签名。如果 macOS 第一次阻止打开，请到“系统设置 → 隐私与安全性”中手动允许。

## 系统要求

- macOS 13 Ventura 或更高版本
- Apple Silicon Mac（`arm64` 构建）
- 不需要网络连接或在线书源

## 从源码构建

```bash
chmod +x build.sh build-dmg.sh
./build.sh
open build/MenuReader.app
```

生成 DMG 安装包：

```bash
./build-dmg.sh
```

## 基本使用

1. 启动应用，点击菜单栏中的 QuietReader 图标。
2. 从书籍菜单导入本地 TXT 文件。
3. 连接多台显示器时，在“显示屏幕”中选择目标屏幕。
4. 选择“居中”打开悬浮阅读窗。
5. 点击 `▶` 开始自动播放。
6. 使用倍速菜单，或点击倍速旁的 `‹ / ›` 调整速度。
7. 点击 `⤢` 打开全览窗口，或进入“设置 → 目录”按章节跳转。

## 项目状态

当前项目专注于 macOS 本地 TXT 阅读。由于实现依赖 macOS AppKit 和 SwiftUI，当前不提供 Windows `.exe` 版本。

## 项目来源与免责声明

QuietReader 基于 [zhiyozhao/menu-reader](https://github.com/zhiyozhao/menu-reader) 进行二次开发。感谢原作者提供基础项目；修改、使用或再分发时，请同时遵守原项目及其依赖项的许可证要求，并保留原作者的版权与许可声明。

本项目只负责显示用户提供的本地文件，不提供小说、在线书源、搜索服务或任何版权内容。用户应自行确保文件来源合法，并对使用、复制和分享内容承担责任。软件按“现状”提供，不保证在所有 macOS 版本、硬件、编码格式或第三方环境下始终正常运行。

## 许可证

MIT License。请同时参阅 [LICENSE](LICENSE)（如仓库中存在）以及原项目的许可证条款。
