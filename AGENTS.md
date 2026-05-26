# AGENTS.md - MenuReader

## 项目概述

macOS 菜单栏小说阅读器，Swift/SwiftUI + AppKit 实现，使用 Swift Package Manager 构建。

## 关键文件

- `MenuReader/MenuReaderApp.swift` - 应用入口，NSStatusItem 菜单栏 UI
- `MenuReader/ReaderStore.swift` - 核心状态管理，播放控制，书库管理
- `MenuReader/CenterDisplayWindow.swift` - 居中显示模式（NSPanel 浮窗）
- `MenuReader/SettingsWindow.swift` - 设置界面（NSTabViewController + SwiftUI）
- `MenuReader/Services.swift` - 存储、文本加载、分页算法
- `MenuReader/HotKeyManager.swift` - 全局快捷键（KeyboardShortcuts 库）
- `MenuReader/ShortcutNames.swift` - 快捷键名称定义
- `MenuReader/Models.swift` - 数据模型（Book, ReaderLibrary）
- `MenuReader/Constants.swift` - 常量和 UserDefaults Key
- `Package.swift` - SPM 依赖配置（依赖 KeyboardShortcuts 库）

## 构建命令

```bash
# 开发构建
swift build

# Release 构建（创建 .app bundle）
./build.sh

# 启动应用
nohup build/MenuReader.app/Contents/MacOS/MenuReader > /tmp/menureader.log 2>&1 &

# 终止应用
pkill -9 MenuReader
```

注意：需要 Xcode（非 CommandLineTools），因为 KeyboardShortcuts 库使用了 Swift Macros。

## 技术要点

- **平台要求**: macOS 13.0+
- **菜单栏**: NSStatusItem + NSMenu（非 SwiftUI MenuBarExtra，解决宽度耦合问题）
- **快捷键**: sindresorhus/KeyboardShortcuts 库（自定义全局快捷键）
- **居中显示**: NSPanel (borderless, nonactivatingPanel, ignoresMouseEvents)
- **多显示器**: 每个选中屏幕独立 NSPanel 窗口
- **分页**: PageSlicer 支持中文标点断句、禁首标点处理
- **进度存储**: 基于 characterOffset（字符偏移量），pageSize 变更后位置不丢失
- **编码支持**: UTF-8 优先，回退 GB18030

## 默认快捷键

- `⌥⌃O` - 显示/隐藏
- `⌥⌃P` - 播放/暂停
- `⌥⌃H` - 上一页
- `⌥⌃L` - 下一页
- `⌥⌃K` - 上一本书
- `⌥⌃J` - 下一本书
- `⌥⌃;` - 切换显示位置（右侧/居中）

## 开发注意事项

- 右侧模式 status item 宽度固定（基于 pageSize 计算），防止菜单跳动
- 居中模式窗口位置：刘海屏自动下移（safeAreaInsets.top）
- persistLibrary() 有 2 秒防抖，退出时 flushPendingPersist() 强制保存
- didSet 中有 isInitialized guard，防止 init 期间触发副作用
- 设置窗口使用 NSTabViewController (tabStyle: .toolbar) 实现原生图标+文字 tab

## 测试数据

测试小说文件在 `/Users/zhao/Tmp/` 目录下。
