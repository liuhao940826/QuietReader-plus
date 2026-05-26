import AppKit
import SwiftUI

@MainActor
final class CenterDisplayWindow {
    static let shared = CenterDisplayWindow()
    
    private var windows: [String: NSPanel] = [:]
    private var hostingViews: [String: NSHostingView<CenterTextView>] = [:]
    private var screenObserver: Any?
    private var activeSpaceObserver: Any?
    private var windowWidth: CGFloat = 200
    private var selectedScreenIDs: Set<String> = []
    private var currentText: String = ""
    
    private init() {
        windowWidth = Self.widthForPageSize(UserDefaults.standard.integer(forKey: UserDefaultsKey.pageSize))
        selectedScreenIDs = Set(UserDefaults.standard.stringArray(forKey: UserDefaultsKey.selectedScreenIDs) ?? [])
        setupObservers()
    }
    
    static func widthForPageSize(_ pageSize: Int) -> CGFloat {
        let charWidth = NSFont.systemFontSize(for: .regular)
        return CGFloat(pageSize) * charWidth + ReaderConstants.windowPadding
    }
    
    func show(text: String) {
        currentText = text
        let screens = targetScreens()
        
        // Create windows for new screens
        for screen in screens {
            guard let uuid = screen.displayUUID else { continue }
            if windows[uuid] == nil {
                createWindow(for: screen, uuid: uuid)
            }
            hostingViews[uuid]?.rootView = CenterTextView(text: text, width: windowWidth)
            windows[uuid]?.orderFrontRegardless()
        }
        
        // Remove windows for screens no longer selected
        let activeUUIDs = Set(screens.compactMap { $0.displayUUID })
        for uuid in windows.keys where !activeUUIDs.contains(uuid) {
            windows[uuid]?.orderOut(nil)
            windows[uuid]?.close()
            windows.removeValue(forKey: uuid)
            hostingViews.removeValue(forKey: uuid)
        }
    }
    
    func hide() {
        for panel in windows.values {
            panel.orderOut(nil)
        }
    }
    
    func updateWidth(forPageSize pageSize: Int) {
        windowWidth = Self.widthForPageSize(pageSize)
        repositionAll()
        for (uuid, hostingView) in hostingViews {
            hostingView.rootView = CenterTextView(text: currentText, width: windowWidth)
            guard let window = windows[uuid] else { continue }
            window.setFrame(
                NSRect(origin: window.frame.origin, size: NSSize(width: windowWidth, height: ReaderConstants.menuBarHeight)),
                display: true
            )
        }
    }
    
    func updateScreens(_ screenIDs: Set<String>) {
        selectedScreenIDs = screenIDs
        if currentText.isEmpty { return }
        show(text: currentText)
    }
    
    private func targetScreens() -> [NSScreen] {
        if selectedScreenIDs.isEmpty {
            return NSScreen.screens
        }
        return NSScreen.screens.filter { screen in
            guard let uuid = screen.displayUUID else { return false }
            return selectedScreenIDs.contains(uuid)
        }
    }
    
    private func createWindow(for screen: NSScreen, uuid: String) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: ReaderConstants.menuBarHeight),
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
        
        let hostingView = NSHostingView(rootView: CenterTextView(text: currentText, width: windowWidth))
        panel.contentView = hostingView
        
        windows[uuid] = panel
        hostingViews[uuid] = hostingView
        
        positionWindow(panel, on: screen)
    }
    
    private func positionWindow(_ window: NSPanel, on screen: NSScreen) {
        let screenFrame = screen.frame
        let safeAreaTop = screen.safeAreaInsets.top
        let windowHeight = ReaderConstants.menuBarHeight
        
        let x = screenFrame.origin.x + (screenFrame.width / 2) - (windowWidth / 2)
        let y: CGFloat
        
        if safeAreaTop > 0 {
            y = screenFrame.origin.y + screenFrame.height - safeAreaTop
        } else {
            y = screenFrame.origin.y + screenFrame.height - windowHeight
        }
        
        window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
    }
    
    private func repositionAll() {
        for screen in NSScreen.screens {
            guard let uuid = screen.displayUUID, let panel = windows[uuid] else { continue }
            positionWindow(panel, on: screen)
        }
    }
    
    private func setupObservers() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.currentText.isEmpty else { return }
                self.show(text: self.currentText)
            }
        }
        
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.repositionAll()
            }
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
            .frame(width: width, height: ReaderConstants.menuBarHeight)
    }
}

extension Font {
    static let menuBarExtra: Font = .system(size: NSFont.systemFontSize(for: .regular), design: .monospaced)
}

extension NSScreen {
    var displayUUID: String? {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        return "\(screenNumber)"
    }
    
    var displayName: String {
        localizedName
    }
}
