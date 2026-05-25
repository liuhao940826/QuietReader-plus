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
    private var overlapMode: CenterOverlapMode = .overlay
    
    private init() {
        let savedPageSize = UserDefaults.standard.integer(forKey: "pageSize")
        if savedPageSize > 0 {
            windowWidth = Self.widthForPageSize(savedPageSize)
        }
        if let modeString = UserDefaults.standard.string(forKey: "centerOverlapMode"),
           let mode = CenterOverlapMode(rawValue: modeString) {
            overlapMode = mode
        }
    }
    
    static func widthForPageSize(_ pageSize: Int) -> CGFloat {
        let charWidth = NSFont.systemFontSize(for: .regular)
        return CGFloat(pageSize) * charWidth + 16.0
    }
    
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
        windowWidth = Self.widthForPageSize(pageSize)
        if window != nil {
            positionWindow()
            if let textHostingView {
                textHostingView.rootView = CenterTextView(text: textHostingView.rootView.text, width: windowWidth)
            }
        }
    }
    
    func updateOverlapMode(_ mode: CenterOverlapMode) {
        overlapMode = mode
        guard let window else { return }
        
        switch mode {
        case .overlay:
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)) + 1)
        case .below:
            window.level = .statusBar
        }
        positionWindow()
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
        
        switch overlapMode {
        case .overlay:
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)) + 1)
        case .below:
            panel.level = .statusBar
        }
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
        let menuBarHeight: CGFloat = safeAreaTop > 0 ? safeAreaTop : (screenFrame.height - screen.visibleFrame.height - screen.visibleFrame.origin.y + screenFrame.origin.y)
        let windowHeight: CGFloat = 22
        
        let x = screenFrame.origin.x + (screenFrame.width / 2) - (windowWidth / 2)
        let y: CGFloat
        
        switch overlapMode {
        case .overlay:
            if safeAreaTop > 0 {
                y = screenFrame.origin.y + screenFrame.height - safeAreaTop
            } else {
                y = screenFrame.origin.y + screenFrame.height - windowHeight
            }
        case .below:
            y = screenFrame.origin.y + screenFrame.height - menuBarHeight - windowHeight
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
            .font(.menuBarExtra)
            .foregroundColor(.primary)
            .lineLimit(1)
            .frame(width: width, height: 22)
            .background(VisualEffectBackground())
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

extension Font {
    static let menuBarExtra: Font = .system(size: NSFont.systemFontSize(for: .regular), design: .monospaced)
}
