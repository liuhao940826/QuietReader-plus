import AppKit
import SwiftUI

@main
struct MenuReaderApp: App {
    @StateObject private var store = ReaderStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(store: store)
                .onAppear {
                    HotKeyManager.shared.setup(store: store)
                }
        } label: {
            if store.isHidden || store.displayMode == .center {
                Image(systemName: "book.fill")
                    .symbolRenderingMode(.monochrome)
            } else {
                Text(store.currentText)
                    .font(.menuBarExtra)
                    .lineLimit(1)
                    .frame(width: 150, alignment: .leading)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarContent: View {
    @ObservedObject var store: ReaderStore

    var body: some View {
        Button(store.isHidden ? "显示" : "隐藏") {
            store.toggleVisibility()
        }

        Button(store.isPlaying ? "暂停" : "继续") {
            store.togglePlayback()
        }
        .disabled(!store.hasPages)

        Button("上一页") {
            store.previousPage()
        }
        .disabled(!store.hasPages)

        Button("下一页") {
            store.nextPage()
        }
        .disabled(!store.hasPages)

        Divider()

        DisplayModePicker(store: store)
        PageSizePicker(store: store)
        IntervalPicker(store: store)

        Picker("书籍选择", selection: Binding(
            get: { store.currentBookIndex },
            set: { store.selectBook(at: $0) }
        )) {
            ForEach(Array(store.books.enumerated()), id: \.element.id) { index, book in
                Text(book.name).tag(index)
            }
        }
        .pickerStyle(.menu)
        .disabled(store.books.isEmpty)

        Divider()

        Button("设置") {
            openSettings()
        }

        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func openSettings() {
        NSApplication.shared.keyWindow?.close()
        SettingsWindow.shared.show(store: store)
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
