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
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .frame(width: 150, alignment: .leading)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarContent: View {
    @ObservedObject var store: ReaderStore

    private let intervalOptions: [TimeInterval] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

    var body: some View {
        Button(store.isHidden ? "显示" : "隐藏") {
            store.toggleVisibility()
        }
        
        Button(store.displayMode == .center ? "切换到右侧" : "切换到居中") {
            store.toggleDisplayMode()
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

        Picker("翻页间隔", selection: Binding(
            get: { store.pageInterval },
            set: { store.setInterval($0) }
        )) {
            ForEach(intervalOptions, id: \.self) { interval in
                Text(String(format: "%.1f秒", interval)).tag(interval)
            }
        }
        .pickerStyle(.menu)

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
