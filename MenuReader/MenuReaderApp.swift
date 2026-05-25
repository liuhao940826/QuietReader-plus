import AppKit
import Combine
import SwiftUI

@main
struct MenuReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var store: ReaderStore!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = ReaderStore()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        HotKeyManager.shared.setup(store: store)
        
        // Observe store changes to update label
        store.$currentText
            .combineLatest(store.$isHidden, store.$displayMode)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.updateStatusItemLabel()
            }
            .store(in: &cancellables)

        updateStatusItemLabel()
    }
    
    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        let menu = buildMenu()
        
        if store.displayMode == .center {
            statusItem.menu = menu
            button.performClick(nil)
            statusItem.menu = nil
        } else {
            guard let window = button.window else { return }
            let mouseInScreen = NSEvent.mouseLocation
            let mouseInWindow = window.convertPoint(fromScreen: mouseInScreen)
            let mouseInButton = button.convert(mouseInWindow, from: nil)
            menu.popUp(positioning: nil, at: NSPoint(x: mouseInButton.x - 8, y: button.bounds.height), in: button)
        }
    }

    private func updateStatusItemLabel() {
        guard let button = statusItem.button else { return }
        
        if store.isHidden || store.displayMode == .center {
            statusItem.length = NSStatusItem.variableLength
            button.title = ""
            button.image = NSImage(systemSymbolName: "book.fill", accessibilityDescription: "MenuReader")
        } else {
            button.image = nil
            button.title = store.currentText
            button.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize(for: .regular), weight: .regular)
            // Fixed width based on pageSize to prevent jumping
            statusItem.length = CenterDisplayWindow.widthForPageSize(store.pageSize)
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Group 1: Actions
        let hideItem = NSMenuItem(title: store.isHidden ? "显示" : "隐藏", action: #selector(toggleVisibility), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)
        
        let playItem = NSMenuItem(title: store.isPlaying ? "暂停" : "播放", action: #selector(togglePlayback), keyEquivalent: "")
        playItem.target = self
        playItem.isEnabled = store.hasPages
        menu.addItem(playItem)
        
        let prevItem = NSMenuItem(title: "上一页", action: #selector(previousPage), keyEquivalent: "")
        prevItem.target = self
        prevItem.isEnabled = store.hasPages
        menu.addItem(prevItem)
        
        let nextItem = NSMenuItem(title: "下一页", action: #selector(nextPage), keyEquivalent: "")
        nextItem.target = self
        nextItem.isEnabled = store.hasPages
        menu.addItem(nextItem)
        
        menu.addItem(.separator())
        
        // Group 2: Settings submenus
        menu.addItem(buildDisplayModeSubmenu())
        menu.addItem(buildPageSizeSubmenu())
        menu.addItem(buildIntervalSubmenu())
        menu.addItem(buildBookSubmenu())
        
        menu.addItem(.separator())
        
        // Group 3: Settings & Quit
        let settingsItem = NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    // MARK: - Submenus
    
    private func buildDisplayModeSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "显示位置", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        
        let rightItem = NSMenuItem(title: "右侧", action: #selector(setDisplayModeRight), keyEquivalent: "")
        rightItem.target = self
        rightItem.state = store.displayMode == .right ? .on : .off
        submenu.addItem(rightItem)
        
        let centerItem = NSMenuItem(title: "居中", action: #selector(setDisplayModeCenter), keyEquivalent: "")
        centerItem.target = self
        centerItem.state = store.displayMode == .center ? .on : .off
        submenu.addItem(centerItem)
        
        item.submenu = submenu
        return item
    }
    
    private func buildPageSizeSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "每页字数", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        
        for size in ReaderOptions.pageSizes {
            let sizeItem = NSMenuItem(title: "\(size)字", action: #selector(setPageSize(_:)), keyEquivalent: "")
            sizeItem.target = self
            sizeItem.tag = size
            sizeItem.state = store.pageSize == size ? .on : .off
            submenu.addItem(sizeItem)
        }
        
        item.submenu = submenu
        return item
    }
    
    private func buildIntervalSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "翻页间隔", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        
        for interval in ReaderOptions.intervals {
            let intervalItem = NSMenuItem(title: String(format: "%.1f秒", interval), action: #selector(setInterval(_:)), keyEquivalent: "")
            intervalItem.target = self
            intervalItem.representedObject = interval
            intervalItem.state = store.pageInterval == interval ? .on : .off
            submenu.addItem(intervalItem)
        }
        
        item.submenu = submenu
        return item
    }
    
    private func buildBookSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "书籍选择", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        
        if store.books.isEmpty {
            let emptyItem = NSMenuItem(title: "无书籍", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for (index, book) in store.books.enumerated() {
                let bookItem = NSMenuItem(title: book.name, action: #selector(selectBook(_:)), keyEquivalent: "")
                bookItem.target = self
                bookItem.tag = index
                bookItem.state = store.currentBookIndex == index ? .on : .off
                submenu.addItem(bookItem)
            }
        }
        
        item.submenu = submenu
        return item
    }
    
    // MARK: - Actions
    
    // MARK: - Actions
    
    @objc private func toggleVisibility() { store.toggleVisibility() }
    @objc private func togglePlayback() { store.togglePlayback() }
    @objc private func previousPage() { store.previousPage() }
    @objc private func nextPage() { store.nextPage() }
    @objc private func setDisplayModeRight() { store.displayMode = .right }
    @objc private func setDisplayModeCenter() { store.displayMode = .center }
    
    @objc private func setPageSize(_ sender: NSMenuItem) {
        store.pageSize = sender.tag
    }
    
    @objc private func setInterval(_ sender: NSMenuItem) {
        if let interval = sender.representedObject as? TimeInterval {
            store.setInterval(interval)
        }
    }
    
    @objc private func selectBook(_ sender: NSMenuItem) {
        store.selectBook(at: sender.tag)
    }
    
    @objc private func openSettings() {
        SettingsWindow.shared.show(store: store)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
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
            }
        }
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
