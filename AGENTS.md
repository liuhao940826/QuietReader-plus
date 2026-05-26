# AGENTS.md - MenuReader

## 项目概述

macOS 菜单栏小说阅读器，Swift/SwiftUI + AppKit，Swift Package Manager 构建。单 executable target，所有源码在 `MenuReader/` 目录。

## 构建命令

```bash
# 开发构建（类型检查）
swift build

# Release 构建（创建 .app bundle，仅 arm64）
./build.sh

# 启动应用
nohup build/MenuReader.app/Contents/MacOS/MenuReader > /tmp/menureader.log 2>&1 &

# 终止应用
pkill -9 MenuReader
```

**必须使用完整 Xcode**（非 CommandLineTools）— KeyboardShortcuts 库依赖 Swift Macros，CommandLineTools 编译会失败。

## 关键文件

| 文件 | 职责 |
|------|------|
| `MenuReaderApp.swift` | 应用入口，NSStatusItem + NSMenu 菜单栏 UI |
| `ReaderStore.swift` | 核心状态（@MainActor），播放/翻页/书库，所有 UI 联动的中枢 |
| `CenterDisplayWindow.swift` | 居中浮窗（NSPanel），多显示器每屏独立窗口 |
| `SettingsWindow.swift` | NSTabViewController + SwiftUI 混合设置界面 |
| `Services.swift` | ReaderStorage / TextBookLoader / PageSlicer 分页算法 |
| `HotKeyManager.swift` | 全局快捷键注册（sindresorhus/KeyboardShortcuts） |
| `Models.swift` | Book, ReaderLibrary 数据模型（Codable） |
| `Constants.swift` | UserDefaults key 和数值常量 |

## 架构要点

- **菜单栏用 NSStatusItem + NSMenu**，不是 SwiftUI MenuBarExtra（因宽度需固定控制）
- **居中模式**: NSPanel (borderless, nonactivatingPanel, ignoresMouseEvents)，刘海屏自动偏移 safeAreaInsets.top
- **分页 (PageSlicer)**: 基于 characterOffset 存储进度，pageSize 变更不丢失位置；支持中文标点断句、禁首标点
- **编码**: UTF-8 优先，回退 GB18030
- **持久化**: persistLibrary() 有 2 秒防抖（`persistDebounceDelay`），退出时 `flushPendingPersist()` 强制写入

## 开发陷阱

- **必须用 .app bundle 启动**：裸二进制 `.build/debug/MenuReader` 不会加载 Info.plist，导致 LSUIElement 等配置失效（设置窗口弹不出来等）。debug 也用 `./build.sh` 后从 bundle 启动
- `ReaderStore` 属性的 `didSet` 中有 `isInitialized` guard，init 期间不触发副作用 — 新增 @Published 属性必须遵守同样模式
- 右侧模式 status item 宽度基于 pageSize 固定计算，改动 pageSize 逻辑需同步更新宽度
- `selectedScreenIDs` 空集表示"全部屏幕"，非空才是选中子集 — 注意边界语义
- 设置窗口是 NSTabViewController (tabStyle: .toolbar)，不是纯 SwiftUI

## 测试数据

测试小说文件在 `/Users/zhao/Tmp/` 目录下。无自动化测试。
