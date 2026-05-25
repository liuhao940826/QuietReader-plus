# MenuReader Refactor Design

## Objective

在不改变当前交互和功能的前提下，重构 MenuReader 的内部结构，解决状态、UI、持久化、分页逻辑混杂的问题，降低后续继续迭代时的回归风险。

## Current State Summary

- `MenuReader/MenuReaderApp.swift` 同时承担 App 入口、菜单 UI、书库管理窗口、快捷键注册。
- `MenuReader/BookManager.swift` 同时承担 model、UserDefaults 持久化、TXT 读取、分页、自动翻页、菜单事件桥接。
- 菜单点击路径不统一：部分逻辑直接调用 store，部分通过 `NotificationCenter` 间接触发。
- `Book` 结构和分页逻辑耦合在同一个文件里，难以独立验证和替换。

## Approved Refactor Direction

只重构结构，不改产品行为：

1. 拆分 model、service、state、UI 责任。
2. 用单一 `ReaderStore` 管理所有可变状态和动作。
3. 将 TXT 读取、分页、持久化从 store 中拆出为独立 service。
4. 去掉菜单点击相关的 `NotificationCenter` 桥接。
5. 将快捷键管理、菜单 UI、书库窗口 UI 从 App 入口拆开。

## Target Structure

### Models

- `MenuReader/Models/Book.swift`
  - 定义书籍持久化结构。

### Services

- `MenuReader/Services/BookLibraryStore.swift`
  - 负责 UserDefaults 读写。
- `MenuReader/Services/TextBookLoader.swift`
  - 负责读取 TXT 文件内容。
- `MenuReader/Services/PageSlicer.swift`
  - 负责文本清洗与分页。

### State

- `MenuReader/State/ReaderStore.swift`
  - 持有当前书库、当前书、当前页、当前间隔、隐藏状态、播放状态。
  - 对外提供统一动作：翻页、切书、导入、删除、设置间隔、切换显示等。

### UI

- `MenuReader/UI/MenuBarContent.swift`
  - 菜单栏一级/二级菜单。
- `MenuReader/UI/LibraryManagerWindow.swift`
  - 书库管理窗口和 SwiftUI 内容。
- `MenuReader/UI/HotKeyController.swift`
  - 全局快捷键注册。

### App

- `MenuReader/MenuReaderApp.swift`
  - 仅负责装配 `ReaderStore`、菜单栏标签、生命周期初始化。

## Implementation Phases

### Phase 1: Extract stable domain pieces

- 抽出 `Book` model。
- 抽出分页 service，并保持当前分页行为不变：
  - 统一清洗换行和制表符。
  - 每页固定 20 个字符宽度。
  - 尽量在空格附近断开。

### Phase 2: Extract persistence and file loading

- 抽出 UserDefaults 书库持久化。
- 抽出 TXT 读取逻辑。
- 明确失败路径：读取失败时不污染现有状态。

### Phase 3: Build `ReaderStore`

- 把现有 `BookManager` 的核心职责迁移到 `ReaderStore`。
- 去掉 `NotificationCenter` 事件桥接。
- 保持现有快捷键、书库进度恢复、自动翻页行为不变。

### Phase 4: Split UI wiring

- 菜单 UI、书库窗口、快捷键控制器拆文件。
- App 入口只保留装配逻辑。

### Phase 5: Verify and clean up

- 删除不再使用的旧实现和桥接代码。
- 构建 release app 验证。
- 手动验证核心路径：
  - 菜单打开
  - 书籍切换
  - 间隔切换
  - 快捷键
  - 书库管理

## Verification

- `swift build`
- `./build.sh`
- 手动运行 `open build/MenuReader.app`

## Risks / Notes

- `MenuBarExtra` 的原生菜单样式和 SwiftUI `Menu` 的行为容易受结构影响，重构时不要随意改变当前菜单呈现方式。
- 快捷键必须继续使用 `HotKey`，但初始化逻辑应移出菜单视图，避免依赖菜单展开才注册。
- 书籍页数和阅读进度必须保持跨启动持久化。
