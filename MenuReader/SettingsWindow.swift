import AppKit
import SwiftUI
import ServiceManagement
import KeyboardShortcuts

@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    static let shared = SettingsWindow()
    
    private var window: NSWindow?
    private var store: ReaderStore?
    
    private override init() {}
    
    func show(store: ReaderStore) {
        self.store = store
        
        if window == nil {
            let tabVC = NSTabViewController()
            tabVC.tabStyle = .toolbar
            
            let generalTab = NSHostingController(rootView: GeneralSettingsView(store: store))
            generalTab.title = "通用"
            let generalItem = NSTabViewItem(viewController: generalTab)
            generalItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "通用")
            
            let libraryTab = NSHostingController(rootView: LibrarySettingsView(store: store))
            libraryTab.title = "书库"
            let libraryItem = NSTabViewItem(viewController: libraryTab)
            libraryItem.image = NSImage(systemSymbolName: "books.vertical", accessibilityDescription: "书库")
            
            let shortcutsTab = NSHostingController(rootView: ShortcutsSettingsView())
            shortcutsTab.title = "快捷键"
            let shortcutsItem = NSTabViewItem(viewController: shortcutsTab)
            shortcutsItem.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "快捷键")

            let outlineTab = NSHostingController(rootView: OutlineSettingsView(store: store))
            outlineTab.title = "目录"
            let outlineItem = NSTabViewItem(viewController: outlineTab)
            outlineItem.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "目录")
            
            tabVC.addTabViewItem(generalItem)
            tabVC.addTabViewItem(libraryItem)
            tabVC.addTabViewItem(shortcutsItem)
            tabVC.addTabViewItem(outlineItem)
            
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            newWindow.title = "设置"
            newWindow.contentViewController = tabVC
            newWindow.center()
            newWindow.isReleasedWhenClosed = false
            newWindow.toolbarStyle = .preference
            newWindow.delegate = self
            
            window = newWindow
        }
        
        // LSUIElement apps need .accessory policy to reliably show windows
        NSApp.setActivationPolicy(.accessory)
        window?.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            // Restore LSUIElement behavior: hide from Cmd+Tab
            NSApp.setActivationPolicy(.prohibited)
        }
    }
}


struct OutlineSettingsView: View {
    @ObservedObject var store: ReaderStore

    var body: some View {
        Group {
            if store.chapters.isEmpty {
                Text("没有识别到章节标题")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(store.chapters) { chapter in
                    Button {
                        store.jumpToChapter(chapter)
                    } label: {
                        Text(chapter.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var store: ReaderStore
    @AppStorage(UserDefaultsKey.launchAtLogin) private var launchAtLogin = false
    
    var body: some View {
        Form {
            Section {
                Toggle("开机自启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
            }
            
            Section("显示") {
                DisplayModePicker(store: store)
                    .pickerStyle(.radioGroup)
                PageSizePicker(store: store)
                IntervalPicker(store: store)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }
}

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("隐藏/显示:", name: .toggleVisibility)
            KeyboardShortcuts.Recorder("切换显示位置:", name: .toggleDisplayMode)
            KeyboardShortcuts.Recorder("暂停/继续:", name: .togglePlayback)
            KeyboardShortcuts.Recorder("上一页:", name: .previousPage)
            KeyboardShortcuts.Recorder("下一页:", name: .nextPage)
            KeyboardShortcuts.Recorder("上一本书:", name: .previousBook)
            KeyboardShortcuts.Recorder("下一本书:", name: .nextBook)
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct LibrarySettingsView: View {
    @ObservedObject var store: ReaderStore

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    if store.books.isEmpty {
                        Text("书库为空，请添加书籍")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(store.books.enumerated()), id: \.element.id) { index, book in
                            HStack(spacing: 10) {
                                Image(systemName: index == store.currentBookIndex ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(index == store.currentBookIndex ? Color.accentColor : Color.secondary.opacity(0.5))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(book.name)
                                        .lineLimit(1)
                                    Text("第 \(book.currentPage + 1) / \(max(book.totalPages, 1)) 页")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    store.removeBook(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .help("删除书籍")
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard index != store.currentBookIndex else { return }
                                store.selectBook(at: index)
                            }
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
            .formStyle(.grouped)
            .padding()
            
            HStack {
                Spacer()
                Button("添加书籍") {
                    store.addBooks()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Shared Picker Components

struct DisplayModePicker: View {
    @ObservedObject var store: ReaderStore
    
    var body: some View {
        Picker("显示位置", selection: $store.displayMode) {
            Text("右侧").tag(ReaderStore.DisplayMode.right)
            Text("居中").tag(ReaderStore.DisplayMode.center)
        }
    }
}

struct PageSizePicker: View {
    @ObservedObject var store: ReaderStore
    
    var body: some View {
        Picker("每页字数", selection: $store.pageSize) {
            ForEach(ReaderOptions.pageSizes, id: \.self) { size in
                Text("\(size)字").tag(size)
            }}
    }
}

struct IntervalPicker: View {
    @ObservedObject var store: ReaderStore
    
    var body: some View {
        Picker("翻页间隔", selection: Binding(
            get: { store.pageInterval },
            set: { store.setInterval($0) }
        )) {
            ForEach(ReaderOptions.intervals, id: \.self) { interval in
                Text(String(format: "%.1f秒", interval)).tag(interval)
            }
        }
    }
}
