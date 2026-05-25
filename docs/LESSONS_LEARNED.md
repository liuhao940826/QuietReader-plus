# MenuReader 开发经验总结

## SwiftUI MenuBarExtra 的限制

### 宽度问题

MenuBarExtra 无法精确控制菜单栏按钮的宽度。当文本长度变化时（如翻页），菜单栏项会跳动。SwiftUI 没有暴露 `NSStatusItem.length` 属性。

### 无法固定位置

MenuBarExtra 由系统管理位置，无法阻止用户拖拽或被系统重新排列。对于需要稳定显示文本的场景不够可靠。

### 最终方案

放弃 MenuBarExtra，直接使用 `NSStatusItem` + `NSMenu`：

```swift
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

// 固定宽度防止菜单栏跳动
statusItem.length = CenterDisplayWindow.widthForPageSize(store.pageSize)

// 使用等宽字体确保字符宽度一致
button.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize(for: .regular), weight: .regular)
```

结合 `@NSApplicationDelegateAdaptor` 使用 AppDelegate 管理生命周期。

## KeyboardShortcuts 库的选择

### 为什么不用 HotKey

[HotKey](https://github.com/soffes/HotKey) 功能简单，但不提供快捷键录制 UI。用户无法自定义快捷键。

### 为什么用 KeyboardShortcuts

[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 优势：
- 提供 SwiftUI `Recorder` 组件，用户可直接在设置中录制快捷键
- 自动处理快捷键冲突
- 自动持久化到 UserDefaults
- SPM 支持

```swift
// 定义快捷键名称和默认值
extension KeyboardShortcuts.Name {
    static let toggleVisibility = Self("toggleVisibility", default: .init(.o, modifiers: [.option, .control]))
}

// 注册回调
KeyboardShortcuts.onKeyUp(for: .toggleVisibility) { [weak store] in
    store?.toggleVisibility()
}

// 设置界面中使用 Recorder
KeyboardShortcuts.Recorder("隐藏/显示:", name: .toggleVisibility)
```

### 注意：需要 Xcode 编译

KeyboardShortcuts 使用了 Swift Macro（`@AddCompletionHandler` 等），**必须用 Xcode 或完整 Xcode toolchain 编译**。仅安装 CommandLineTools 会报错：

```
error: macro implementation type 'KeyboardShortcutsXcodeIntegration.AddCompletionHandlerMacro' could not be found
```

解决方案：确保 `xcode-select -p` 指向 Xcode.app：
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## 居中显示模式的实现

参考 [boring.notch](https://github.com/TheBoredTeam/boring.notch) 的思路，使用 NSPanel 作为浮窗 overlay：

```swift
let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: 22),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)

panel.level = .statusBar
panel.backgroundColor = .clear
panel.isOpaque = false
panel.hasShadow = false
panel.ignoresMouseEvents = true  // 不拦截鼠标事件
panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
```

关键配置：
- `.nonactivatingPanel`：点击不会夺取焦点
- `.ignoresMouseEvents = true`：完全透明于鼠标操作
- `.canJoinAllSpaces, .stationary`：所有桌面空间可见
- `.level = .statusBar`：显示在菜单栏层级

### 刘海屏适配

```swift
let safeAreaTop = screen.safeAreaInsets.top

if safeAreaTop > 0 {
    // 有刘海：放在刘海下方
    y = screenFrame.origin.y + screenFrame.height - safeAreaTop
} else {
    // 无刘海：放在菜单栏内
    y = screenFrame.origin.y + screenFrame.height - windowHeight
}
```

## 分页算法中的禁首标点处理

分页不能让标点出现在下一页开头（"禁首标点"规则）。

实现方式：找到断页点后，如果下一页的第一个字符是禁首字符，就把它吸入当前页：

```swift
private static let noStartCharacters: Set<Character> = [
    "。", "！", "？", "；", "：", "，", "、",
    ".", ",", "!", "?", ";", ":",
    "）", "」", "』", "》", "】", "〉",
    ")", "]", "}",
    "\u{201D}", "\u{2019}", // 闭合弯引号
    "…"
]

// 在 bestBreakIndex 中
var end = preferred ?? hardEnd
while end < characters.count, noStartCharacters.contains(characters[end]) {
    end += 1
}
```

这意味着某些页可能超过 `pageSize` 几个字符，但排版更合理。

## 字符偏移量 vs 页码作为进度存储

### 问题

如果只存页码（`currentPage`），用户修改每页字数后，页码对应的内容会完全错位。

### 解决方案

存储 `characterOffset`（当前页在原文中的起始字符位置）：

```swift
struct Book: Codable {
    var currentPage: Int       // 仅用于 UI 显示
    var characterOffset: Int   // 实际进度标记
}

// 保存时
books[currentBookIndex].characterOffset = pages[currentPage].startOffset

// 恢复时（重新分页后）
currentPage = PageSlicer.pageIndex(forCharacterOffset: offset, in: pages)
```

`pageIndex(forCharacterOffset:)` 遍历新分出的页面，找到包含该偏移量的页。

## NSTabViewController 的 toolbar 样式设置页

macOS 原生设置窗口的标签页样式（如系统偏好设置）：

```swift
let tabVC = NSTabViewController()
tabVC.tabStyle = .toolbar  // 关键：工具栏样式

let generalTab = NSHostingController(rootView: GeneralSettingsView(store: store))
generalTab.title = "通用"
let generalItem = NSTabViewItem(viewController: generalTab)
generalItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "通用")

tabVC.addTabViewItem(generalItem)

let window = NSWindow(...)
window.contentViewController = tabVC
window.toolbarStyle = .preference  // 偏好设置样式的 toolbar
```

注意 `toolbarStyle = .preference` 使图标和文字紧凑排列，与系统设置一致。

## Form(.grouped) 的 Section 样式和限制

SwiftUI 的 `Form` 配合 `.formStyle(.grouped)` 可以得到类似系统设置的卡片分组样式：

```swift
Form {
    Section {
        Toggle("开机自启动", isOn: $launchAtLogin)
    }
    Section("显示") {
        DisplayModePicker(store: store)
        PageSizePicker(store: store)
    }
}
.formStyle(.grouped)
```

注意事项：
- `.grouped` 样式下 Section 有标题时会显示灰色小标题
- 无标题 Section 则只是分组卡片
- 需要 `.padding()` 避免内容贴边
- 列表类内容的高度需要用 `.frame(maxHeight:)` 限制，否则会无限增长

## 菜单弹出位置的处理

### popUp vs statusItem.menu

两种方式弹出菜单，行为不同：

**方式一：statusItem.menu（系统默认）**

```swift
statusItem.menu = menu
button.performClick(nil)
statusItem.menu = nil  // 用完立即置空，否则下次点击不触发 action
```

菜单会精确对齐在状态栏项正下方，但需要手动管理 menu 的设置和清除。

**方式二：popUp（手动定位）**

```swift
let mouseInScreen = NSEvent.mouseLocation
let mouseInWindow = window.convertPoint(fromScreen: mouseInScreen)
let mouseInButton = button.convert(mouseInWindow, from: nil)
menu.popUp(positioning: nil, at: NSPoint(x: mouseInButton.x - 8, y: button.bounds.height), in: button)
```

更灵活，可以控制弹出位置。适合右侧模式下菜单需要在文字上方弹出的场景。

### 实际选择

本项目中：
- 居中模式用 `statusItem.menu`（图标在固定位置，系统对齐即可）
- 右侧模式用 `popUp`（状态栏文字可能很宽，需要在点击位置附近弹出）

## 固定宽度防止菜单跳动

菜单栏文本内容变化时（如翻页），如果宽度跟随文本长度变化，会导致其他状态栏图标跳动。

解决方案：

```swift
// 根据每页字数计算固定宽度
static func widthForPageSize(_ pageSize: Int) -> CGFloat {
    let charWidth = NSFont.systemFontSize(for: .regular)
    return CGFloat(pageSize) * charWidth + 8.0
}

// 应用固定宽度
statusItem.length = CenterDisplayWindow.widthForPageSize(store.pageSize)

// 配合等宽字体
button.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize(for: .regular), weight: .regular)
```

等宽字体 + 固定宽度 = 无跳动。

## macOS 开发中的 Xcode vs CommandLineTools 区别

| 项目 | CommandLineTools | Xcode.app |
|------|-----------------|-----------|
| Swift 编译器 | 有 | 有 |
| Swift Macro 支持 | 无 | 有 |
| iOS/macOS SDK | 基础 | 完整 |
| Interface Builder | 无 | 有 |
| 代码签名 | 有限 | 完整 |
| xcrun 工具链 | 基础 | 完整 |

当依赖库使用了 Swift Macro（如 KeyboardShortcuts）时，必须安装完整 Xcode 并切换：

```bash
# 查看当前开发者路径
xcode-select -p

# 切换到 Xcode
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 切换回 CommandLineTools
sudo xcode-select -s /Library/Developer/CommandLineTools
```

SPM 构建命令不变（`swift build`），但底层工具链不同会影响 Macro 展开。
