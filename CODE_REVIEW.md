# MenuReader 代码审查报告

> 审查日期: 2026-05-26

## 项目概况

macOS 菜单栏小说阅读器，代码量约 1200 行，结构清晰。整体是一个**质量不错的个人项目**。

### 文件结构

| 文件 | 行数 | 职责 |
|------|------|------|
| ReaderStore.swift | 359 | 核心状态管理（最大文件） |
| MenuReaderApp.swift | 259 | 应用入口、菜单栏 UI |
| SettingsWindow.swift | 217 | 设置界面 |
| CenterDisplayWindow.swift | 192 | 居中显示浮窗 |
| Services.swift | 149 | 存储、文本加载、分页 |
| HotKeyManager.swift | 43 | 全局快捷键注册 |
| Models.swift | 29 | 数据模型 |
| Constants.swift | 18 | 常量定义 |
| ShortcutNames.swift | 11 | 快捷键定义 |

---

## 第一轮审查 (2026-05-26)

### 1. God Class: ReaderStore.swift

**严重程度**: 高
**位置**: MenuReader/ReaderStore.swift (359行)

这个类承担了太多职责：
- 显示状态管理（可见性、显示模式、当前文本）
- 播放控制（定时器、播放/暂停）
- 书库管理（增删改查）
- 翻页导航
- 屏幕选择
- 持久化协调

**建议拆分为**:
ReaderStore (协调层)
- PlaybackController (定时器、播放控制)
- BookLibrary (书籍CRUD)
- DisplayController (可见性、显示模式)

---

### 2. 单例紧耦合

**严重程度**: 中
**位置**: ReaderStore.swift:36-37, 238, 286-289

ReaderStore 直接调用单例，导致与 CenterDisplayWindow 紧密耦合，难以测试和替换。

**建议**: 使用协议注入

---

### 3. UserDefaults Key 分散 - 已修复

**状态**: 已修复
**修复方式**: 新建 Constants.swift，集中管理所有 Key

---

### 4. 魔法数字 - 已修复

**状态**: 已修复
**修复方式**: 在 Constants.swift 中定义 ReaderConstants

---

### 5. 强制解包风险 - 已修复

**状态**: 已修复
**位置**: CenterDisplayWindow.swift:67-71

---

### 6. 静默失败的错误处理

**严重程度**: 中
**位置**: Services.swift:19-21

用户数据保存失败时没有任何提示，可能导致进度丢失。

**建议**: 至少添加日志，或者抛出错误让上层处理。

---

### 7. 废弃 API 使用 - 已修复

**状态**: 已修复
**位置**: SettingsWindow.swift:73

---

### 8. 组件位置不当 - 已修复

**状态**: 已修复

DisplayModePicker、PageSizePicker、IntervalPicker 已移动到 SettingsWindow.swift 底部。

---

### 9. 状态同步隐患

**严重程度**: 低
**位置**: ReaderStore.swift:13-14

currentPage 和 totalPages 非 @Published，但 LibrarySettingsView 通过 book.currentPage 显示页码，存在潜在的同步问题。

---

### 10. 缺少单元测试

PageSlicer 和 ReaderTextPipeline 是纯函数，非常适合单元测试，但项目没有测试。

---

## 代码亮点

1. **清晰的文件分离** - 每个文件职责明确
2. **良好的中文标点处理** - PageSlicer 对中文断句的处理很细致
3. **防抖持久化** - persistLibrary() 使用 Task 防抖，避免频繁写入
4. **字符偏移量恢复** - 切换 pageSize 后能正确恢复阅读位置
5. **@MainActor 使用正确** - 主线程安全处理得当

---

## 第一轮重构状态

| 优先级 | 任务 | 状态 |
|--------|------|------|
| 高 | 修复强制解包 | 已修复 
| 中 | 提取常量替换魔法数字 | 已修复 |
| 中 | 修复废弃 API | 已修复 |
| 中 | 移动 Picker 组件 | 已修复 |
| 中 | 添加错误处理/日志 | 待处理 |
| 低 | 拆分 ReaderSt题

| 问题 | 严重程度 | 位置 | 说明 |
|------|----------|------|------|
| God Class | 低 | ReaderStore.swift | 359行，职责较多，但对于这个规模的项目可以接受 |
| 单例耦合 | 低 | ReaderStore -> CenterDisplayWindow.shared | 可用协议解耦，但当前也能正常工作 |
| 静默失败 | 中 | Services.swift:20 | saveLibrary 编码失败时无提示，可能丢失数据 |
| 缺少单元测试 | 低 | - | PageSlicer 是核心逻辑，适合添加测试 |

### 建议改进

#### 1. 添加保存失败的日志（推荐）

**工作量**: 5分钟
**位置**: Sern**说明**: PageSlicer 是分页核心逻辑，纯函数设计非常适合单元测试

测试用例建议：
- 空字符串输入
- 短于一页的文本
- 中文标点断句
- 不可断行字符处理（如闭合引号、省略号）
- pageSize 边界值

---

## 总结

### 当前状态

代码质量**良好**，第一轮发现的 5 个高/中优先级问题已全部修复：
- 强制解包
- UserDefaults Key 分散
- 魔法数字
- 废弃 API
- 组件位置

### 后续建议

| 优先级 | 任务 | 工作量 | 必要性 |
|--------|------|--------|--------|
| 中 | 添加保存失败日志 | 5分钟 | 推荐，防止数据丢失无感知 |
| 低 | 为 PageSlicer 添加单元测试 | 30分钟 | 可选，提高核心逻辑可靠性 |
| 低 | 拆分 ReaderStore | 2小时 | 可选，当前规模可接受 |
| 低 | 协议解耦单例 | 1小时 | 可选，除非需要单元测试 |

### 结论

对于个人项目来说，当前代码质量已经**很好**。如果只是自用，无需进一步重构。如果计划开源或长期维护，建议优先添加保存失败的日志处理。
