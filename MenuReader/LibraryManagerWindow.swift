import AppKit
import SwiftUI

final class LibraryManagerWindow: NSWindowController {
    static let shared = LibraryManagerWindow()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "书库管理"
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(store: ReaderStore) {
        let view = LibraryManagerView(store: store) {
            self.close()
        }

        window?.contentView = NSHostingView(rootView: view)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct LibraryManagerView: View {
    @ObservedObject var store: ReaderStore
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("书库管理")
                .font(.headline)

            if store.books.isEmpty {
                Text("书库为空，请添加书籍")
                    .foregroundStyle(.secondary)
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
                .frame(height: 260)
            }

            HStack {
                Button("添加书籍") {
                    store.addBooks()
                }

                Spacer()

                Button("关闭") {
                    onClose()
                }
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}
