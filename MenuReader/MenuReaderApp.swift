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

    private let intervalOptions: [TimeInterval] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

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

        Picker("显示位置", selection: Binding(
            get: { store.displayMode },
            set: { store.displayMode = $0 }
        )) {
            Text("右侧").tag(ReaderStore.DisplayMode.right)
            Text("居中").tag(ReaderStore.DisplayMode.center)
        }
        .pickerStyle(.menu)

        Picker("每页字数", selection: Binding(
            get: { store.pageSize },
            set: { store.pageSize = $0 }
        )) {
            Text("10字").tag(10)
            Text("20字").tag(20)
            Text("30字").tag(30)
            Text("40字").tag(40)
            Text("50字").tag(50)
            Text("60字").tag(60)
        }
        .pickerStyle(.menu)

        Picker("翻页间隔", selection: Binding(
            get: { store.pageInterval },
            set: { store.setInterval($0) }
        )) {
            ForEach(intervalOptions, id: \.self) { interval in
                Text(String(format: "%.1f秒", interval)).tag(interval)
            }
        }
        .pickerStyle(.menu)

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
