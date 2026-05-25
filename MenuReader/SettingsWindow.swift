import AppKit
import SwiftUI
import ServiceManagement
import KeyboardShortcuts

final class SettingsWindow {
    static let shared = SettingsWindow()
    
    private var window: NSWindow?
    private var store: ReaderStore?
    
    private init() {}
    
    func show(store: ReaderStore) {
        self.store = store
        
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
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
        
        tabVC.addTabViewItem(generalItem)
        tabVC.addTabViewItem(libraryItem)
        tabVC.addTabViewItem(shortcutsItem)
        
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
        
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}


struct GeneralSettingsView: View {
    @ObservedObject var store: ReaderStore
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
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
        Form {
            Section {
                if store.books.isEmpty {
                    Text("书库为空，请添加书籍")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(store.books.enumerated()), id: \.element.id) { index, book in
                        HStack(spacing: 8) {
                            Image(systemName: index == store.currentBookIndex ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(index == store.currentBookIndex ? Color.accentColor : Color.secondary.opacity(0.5))

                            VStack(alignment: .leading, spacing: 4) {
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
            
            Section {
                Button("添加书籍") {
                    store.addBooks()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
