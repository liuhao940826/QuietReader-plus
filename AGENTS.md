# AGENTS.md - MenuReader

## 项目概述

macOS菜单栏小说阅读器，Swift/SwiftUI实现，使用Swift Package Manager构建。

## 关键文件

- `MenuReader/MenuReaderApp.swift` - 应用入口，菜单栏UI，快捷键管理
- `MenuReader/BookManager.swift` - 核心业务逻辑，书库管理，翻页控制
- `MenuReader/Info.plist` - 应用配置
- `Package.swift` - SPM依赖配置（依赖HotKey库）

## 构建命令

```bash
# 开发构建
swift build

# Release构建（创建.app bundle）
./build.sh

# 直接运行（不创建.app）
swift run
```

## 技术要点

- **平台要求**: macOS 13.0+，arm64架构
- **UI框架**: SwiftUI + MenuBarExtra（原生菜单样式）
- **快捷键**: HotKey库实现全局快捷键
- **菜单样式**: 使用`.menuBarExtraStyle(.menu)`实现原生二级菜单
- **二级菜单**: SwiftUI Menu组件，对勾在最右边显示

## 快捷键

- `Ctrl+Shift+H` - 显示/隐藏菜单栏文字
- `Ctrl+Shift+P` - 暂停/继续翻页
- `Ctrl+Shift+B/N` - 上/下一本小说
- `Ctrl+Shift+←/→` - 上/下一页

## 开发注意事项

- 菜单栏宽度固定150px，文字靠左显示
- 每页显示20个字符，不足用空格填充对齐
- 书库数据存储在UserDefaults中
- 使用NotificationCenter处理菜单点击事件
- 对勾使用✓符号，放在文字后面用空格填充对齐

## 测试数据

测试小说文件在`/Users/zhao/Tmp/`目录下，可用于测试书库功能。
