# MenuReader 代码审查报告

> 审查日期: 2026-05-26

## 项目概况

macOS 菜单栏小说阅读器，代码量约 1200 行，结构清晰。整体是一个**质量不错的个人项目**，但存在一些可以改进的地方。

### 文件结构

| 文件 | 行数 | 职责 |
|------|------|------|
| `ReaderStore.swift` | 359 | 核心状态管理（最大文件） |
| `MenuReaderApp.swift` | 299 | 应用入口、菜单栏 UI |
| `CenterDisplayWindow.swift` | 191 | 居中显示浮窗 |
| `SettingsWindow.swift` | 178 | 设置界面 |
| `Services.swift` | 149 | 存储、文本加载、分页 |
| `HotKeyManager.swift` | 43 | 全局快捷键注册 |
| `Models.swift` | 29 | 数据模型 |
| `ShortcutNames.swift` | 11 | 快捷键定义 |

---

## 主要问题

### 1. God Class: `ReaderStore.swift`

**严重程度**: 高  
**位置**: `MenuReader/ReaderStore.swift` (359行)

这个类承担了太多职责：
- 显示状态管理（可见性、显示模式、当前文本）
- 播放控制（定时器、播放/暂停）
- 书库管理（增删改查）
- 翻页导航
- 屏幕选择
- 持久化协调

**建议拆分为**:
```
ReaderStore (协调层)
├── PlaybackController (定时器、播放控制)
├── BookLibrary (书籍CRUD)
└── DisplayController (可见性、显示模式)
```

---

### 2. 单例紧耦合

**严重程度**: 中  
**位置**: `ReaderStore.swift:36-37, 238, 286-289`

```swift
// ReaderStore 直接调用单例
CenterDisplayWindow.shared.updateScreens(selectedScreenIDs)
CenterDisplayWindow.shared.show(text: currentText)
CenterDisplayWindow.shared.hide()
```

导致 `ReaderStore` 与 `CenterDisplayWindow` 紧密耦合，难以测试和替换。

**建议**: 使用协议注入
```swift
protocol TextDisplayable {
    func show(text: String)
    func hide()
}
```

---

### 3. UserDefaults Key 分散

**严重程度**: 中

| 文件 | 行号 | Key |
|------|------|-----|
| `ReaderStore.swift` | 21 | `"displayMode"` |
| `ReaderStore.swift` | 27 | `"pageSize"` |
| `ReaderStore.swift` | 35 | `"selectedScreenIDs"` |
| `CenterDisplayWindow.swift` | 17 | `"pageSize"` ⚠️ 重复 |
| `CenterDisplayWindow.swift` | 21 | `"selectedScreenIDs"` ⚠️ 重复 |
| `Services.swift` | 4 | `"reader.library"` |
| `SettingsWindow.swift` | 67 | `"launchAtLogin"` |

**问题**: 
- Key 字符串分散，容易拼写错误
- `CenterDisplayWindow` 重复读取了 `ReaderStore` 已经管理的配置

**建议**: 集中管理
```swift
enum UserDefaultsKey {
   static let library = "reader.library"
    static let launchAtLogin = "launchAtLogin"
}
```

---

### 4. 魔法数字

**严重程度**: 低

| 位置 | 值 | 含义 |
|------|-----|------|
| `ReaderStore.swift:175` | `1_500_000_000` | 切换书籍延迟 1.5秒 |
| `ReaderStore.swift:353` | `2_000_000_000` | 持久化防抖 2秒 |
| `CenterDisplayWindow.swift:29` | `+ 8.0` | 窗口 padding |
| `CenterDisplayWindow.swift:68, 92, 118` | `height: 22` | 菜单栏高度 |
| `Services.swift:66` | `defaultPageSize = 20` | 默认每页字数 |
| `Services.swift:115` | `hardEnd - 6` | 断句搜索范围 |

**建议**:
```swift
enum ReaderConstants {
    static let menuBarHeight: CGFloat = 22
    static let bookSwitchDelay: UInt64 = 1_500_000_000
    static let persistDebounceDelay: UInt64 = 2_000_000_000
    static let windowPadding: CGFloat = 8.0
}
```

---

### 5. 强制解包风险

**严重程度**: 中  
**位置**: `CenterDisplayWindow.swift:68`

```swift
windows[uuid]?.setFrame(
    NSRect(origin: windows[uuid]!.frame.origin, ...),  // 危险!
    display: true
)
```

**修复**:
```swift
guard let window = windows[uuid] else { continue }
window.setFrame(NSRect(origin: window.frame.origin, ...),程度**: 中  
**位置**: `Services.swift:19-21`

```swift
static func saveLibrary(_ library: ReaderLibrary) {
    guard let data = try? JSONEncoder().encode(library) else { return }  // 静默失败
    UserDefaults.standard.set(data, forKey: libraryKey)
}
```

用户数据保存失败时没有任何提示，可能导致进度丢失。

**建议**: 至少添加日志，或者抛出错误让上层处理。

---

### 7. 废弃 API 使用

**严重程度**: 低  
**位置**: `SettingsWindow.swift:73`

```swift
.onChange(of: launchAtLogin) { newValue in  // macOS 14 已废弃
```

**修复**:
```swift
.onChange(of: launchAtLogin) { oldValue, newValue in
```

---

## 次要问题

### 8. 组件位置不当

`MenuReaderApp.swift:263-299` 定义了 `DisplayModePicker`、`PageSizePicker`、`IntervalPicker`，但这些主要在 `SettingsWindow.swift` 中使用。建议移动到 `SettingsWindow.swift` 或单独的 `Components.swift`。

### 9. 状态同步隐患

`ReaderStore.swift:13-14`:
```swift
private var currentPage: Int = 0   // 非 @Published
private var totalPages: Int = 0    // 非 @Published
```

但 `LibrarySettingsView:139` 通过 `book.currentPage` 显示页码，存在潜在的同步问题。

### 10. 缺少单元测试

`PageSlicer` 和 `ReaderTextPipeline` 是纯函数，非常适合单元测试，但项目没有测试。

---

## 代码亮点

项目也有做得好的地方：

1. **清晰的文件分离** - 每个文件职责明确
2. **良好的中文标点处理** - `PageSlicer` 对中文断句的处理很细致
3. **防抖持久化** - `persistLibrary()` 使用 Task 防抖，避免频繁写入
4. **字符偏移量恢复** - 切换 pageSize 后能正确恢复阅读位置
5. **@MainActor 使用正确** - 主线程安全处理得当

---

## 重构优先级

| 优先级 | 任务 | 工作量 | 位置 |
|--------|------|--------|------|
| 🔴 高 | 修复强制解包 | 5分钟 | `CenterDisplayWindow.swift:68` |
| 🔴 高 | 集中 UserDefaults Key | 15分钟 | 新建 `Constants.swift` |
| 🟡 中 | 提取常量替换魔法数字 | 20分钟 | 多处 |
| 🟡 中 | 修复废弃 API | 5分钟 | `SettingsWindow.swift:73` |
| 🟡 中 | 添加错误处理/日志 | 30分钟 | `Services.swift` |
| 🟢 低 | 拆分 ReaderStore | 2小时 | `ReaderStore.swift` |
| 🟢 低 | 添加单元测试 | 1小时 | 新建测试目录 |

---

## 总结

对于个人项目来说，代码库**质量不错**。主要问题是 `ReaderStore` 承担了过多职责，以及一些小的代码卫生问题。

- **自用**: 当前状态完全可以接受
- **长期维护/开源**: 建议按优先级逐步重构
