import AppKit
import SwiftUI

@MainActor
final class CenterDisplayWindow {
    static let shared = CenterDisplayWindow()
    
    private var window: NSPanel?
    private var textHostingView: NSHostingView<CenterTextView>?
    private var screenObserver: Any?
    private var activeSpaceObserver: Any?
    private var windowWidth: CGFloat = 200
    
    private init() {}
    
    func show(text: String) {
        if window == nil {
            createWindow()
        }
        updateText(text)
        window?.orderFrontRegardless()
    }
    
    func updateText(_ text: String) {
        guard let textHostingView else { return }
        textHostingView.rootView = CenterTextView(text: text, width: windowWidth)
    }
    
    func hide() {
        window?.orderOut(nil)
    }
    
    func updateWidth(forPageSize pageSize: Int) {
        // ~8pt per character for monospaced 12pt font
        let newWidth = CGFloat(pageSize) * 8.0 + 20.0
        windowWidth = newWidth
        if window != nil {
            positionWindow()
        }
    }
    
    func destroy() {
        removeObservers()
        window?.close()
        window = nil
        textHostingView = nil
    }
    
    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: 22),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        
        let hostingView = NSHostingView(rootView: CenterTextView(text: "", width: windowWidth))
        panel.contentView = hostingView
        self.textHostingView = hostingView
        self.window = panel
        
        positionWindow()
        setupObservers()
    }
    
    private func positionWindow() {
        guard let window, let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let safeAreaTop = screen.safeAreaInsets.top
        let windowHeight: CGFloat = 22
        
        let x = screenFrame.origin.x + (screenFrame.width / 2) - (windowWidth / 2)
        let y: CGFloat
        
        if safeAreaTop > 0 {
            // Notch screen: position below the notch
            y = screenFrame.origin.y + screenFrame.height - safeAreaTop
        } else {
            // No notch: position at top edge (inside menu bar)
            y = screenFrame.origin.y + screenFrame.height - windowHeight
        }
        
        window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
    }
    
    private func setupObservers() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.positionWindow()
            }
        }
        
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.positionWindow()
            }
        }
    }
    
    private func removeObservers() {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
        if let observer = activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            activeSpaceObserver = nil
        }
    }
}

struct CenterTextView: View {
    let text: String
    let width: CGFloat
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.primary)
            .lineLimit(1)
            .frame(width: width, height: 22)
    }
}
