import AppKit
import SwiftUI

@MainActor
final class OverviewWindow: NSObject, NSWindowDelegate {
    static let shared = OverviewWindow()
    private var window: NSWindow?

    func show(store: ReaderStore) {
        let view = OverviewView(store: store)
        if window == nil {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "阅读全览"
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.center()
            window = newWindow
        }
        window?.contentView = NSHostingView(rootView: view)
        NSApp.setActivationPolicy(.accessory)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
    }
}

struct OverviewView: View {
    @ObservedObject var store: ReaderStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("全览").font(.title2.bold())
                Text("点击任意段落即可从这里开始阅读")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("第 \(store.currentPageIndex + 1) / \(max(store.pageCount, 1)) 页")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            List(0..<store.pageCount, id: \.self) { index in
                Button {
                    store.jumpToPage(index, startPlayback: true)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .foregroundStyle(index == store.currentPageIndex ? Color.accentColor : .secondary)
                            .frame(width: 45, alignment: .trailing)
                        Text(store.pagePreview(at: index))
                            .foregroundStyle(index == store.currentPageIndex ? Color.accentColor : .primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 6)
            }
        }
        .padding(.vertical)
    }
}
