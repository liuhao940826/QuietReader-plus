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
        
        let settingsView = SettingsView(store: store)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "设置"
        newWindow.contentViewController = hostingController
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @ObservedObject var store: ReaderStore
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(store: store)
                .tabItem {
                    Label("通用", systemImage: "gear")
                }
                .tag(0)
            
            LibrarySettingsView(store: store)
                .tabItem {
                    Label("书库", systemImage: "books.vertical")
                }
                .tag(1)
            
            ShortcutsSettingsView()
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
                }
                .tag(2)
        }
        .frame(width: 600, height: 400)
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
                Picker("显示位置", selection: $store.displayMode) {
                    Text("右侧（状态栏）").tag(ReaderStore.DisplayMode.right)
                    Text("居中（菜单栏中央）").tag(ReaderStore.DisplayMode.center)
                }
                .pickerStyle(.radioGroup)
                
                Picker("每页字数", selection: $store.pageSize) {
                    Text("10字").tag(10)
                    Text("20字").tag(20)
                    Text("30字").tag(30)
                    Text("40字").tag(40)
                    Text("50字").tag(50)
                    Text("60字").tag(60)
                }
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
        VStack(alignment: .leading, spacing: 14) {
            if store.books.isEmpty {
                Text("书库为空，请添加书籍")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(store.books.enumerated()), id: \.element.id) { index, book in
                        HStack(spacing: 12) {
                            Image(systemName: index == store.currentBookIndex ? "book.closed.fill" : "book.closed")
                                .foregroundStyle(index == store.currentBookIndex ? .primary : .secondary)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.name)
                                    .lineLimit(1)

                                Text("第 \(book.currentPage + 1) / \(max(book.totalPages, 1)) 页")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if index == store.currentBookIndex {
                                Label("当前", systemImage: "checkmark")
                                    .labelStyle(.titleAndIcon)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }

                            Button {
                                store.removeBook(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help("删除书籍")
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard index != store.currentBookIndex else { return }
                            store.selectBook(at: index)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(index == store.currentBookIndex ? Color.accentColor.opacity(0.10) : Color.clear)
                                .padding(.vertical, 2)
                        )
                    }
                }
                .listStyle(.inset)
            }

            HStack {
                Button("添加书籍") {
                    store.addBooks()
                }

                Spacer()
            }
        }
        .padding(16)
    }
}
