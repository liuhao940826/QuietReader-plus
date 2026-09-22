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
    private var menuBarAppearance: NSAppearance?
    private var panelOpacity: CGFloat
    private var previousAction: (() -> Void)?
    private var hideAction: (() -> Void)?
    private var playbackAction: (() -> Void)?
    private var slowerAction: (() -> Void)?
    private var fasterAction: (() -> Void)?
    private var speedAction: ((Double) -> Void)?
    private var nextAction: (() -> Void)?
    private var overviewAction: (() -> Void)?
    private var playbackSpeed: Double = 1.0
    private var isPlaying = false
    
    private init() {
        windowWidth = Self.widthForPageSize(UserDefaults.standard.integer(forKey: UserDefaultsKey.pageSize))
        selectedScreenIDs = Set(UserDefaults.standard.stringArray(forKey: UserDefaultsKey.selectedScreenIDs) ?? [])
        panelOpacity = CGFloat(UserDefaults.standard.double(forKey: UserDefaultsKey.panelOpacity))
        if panelOpacity == 0 { panelOpacity = 0.75 }
        setupObservers()
    }
    
    static func widthForPageSize(_ pageSize: Int) -> CGFloat {
        min(max(CGFloat(pageSize) * 14 + 48, 420), 900)
    }

    private static let panelHeight: CGFloat = 176
    
    func show(text: String) {
        currentText = text
        let screens = targetScreens()
        
        // Create windows for new screens
        for screen in screens {
            guard let uuid = screen.displayUUID else { continue }
            if windows[uuid] == nil {
                createWindow(for: screen, uuid: uuid)
            }
            hostingViews[uuid]?.rootView = makeTextView(text: text)
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
            hostingView.rootView = makeTextView(text: currentText)
            guard let window = windows[uuid] else { continue }
            window.setFrame(
                NSRect(origin: window.frame.origin, size: NSSize(width: windowWidth, height: Self.panelHeight)),
                display: true
            )
        }
    }
    
    func updateScreens(_ screenIDs: Set<String>) {
        selectedScreenIDs = screenIDs
        if currentText.isEmpty { return }
        show(text: currentText)
    }
    
    func updateMenuBarAppearance(_ appearance: NSAppearance?) {
        menuBarAppearance = appearance
        for panel in windows.values {
            panel.appearance = appearance
        }
    }

    func setOpacity(_ opacity: CGFloat) {
        panelOpacity = opacity
        UserDefaults.standard.set(Double(opacity), forKey: UserDefaultsKey.panelOpacity)
        for panel in windows.values { panel.alphaValue = opacity }
    }

    func setDisplayedSpeed(_ speed: Double) {
        playbackSpeed = speed
        for (uuid, hostingView) in hostingViews {
            hostingView.rootView = makeTextView(text: currentText)
            _ = uuid
        }
    }

    func setPlaybackState(_ playing: Bool) {
        isPlaying = playing
        for hostingView in hostingViews.values {
            hostingView.rootView = makeTextView(text: currentText)
        }
    }

    func setPageActions(hide: @escaping () -> Void, playback: @escaping () -> Void, slower: @escaping () -> Void, faster: @escaping () -> Void, speed: @escaping (Double) -> Void, previous: @escaping () -> Void, next: @escaping () -> Void, overview: @escaping () -> Void) {
        hideAction = hide
        playbackAction = playback
        slowerAction = slower
        fasterAction = faster
        speedAction = speed
        previousAction = previous
        nextAction = next
        overviewAction = overview
        for hostingView in hostingViews.values {
            hostingView.rootView = makeTextView(text: currentText)
        }
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
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: Self.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        panel.isOpaque = true
        panel.hasShadow = true
        panel.alphaValue = panelOpacity
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.appearance = menuBarAppearance
        
        let hostingView = NSHostingView(rootView: makeTextView(text: currentText))
        panel.contentView = hostingView
        
        windows[uuid] = panel
        hostingViews[uuid] = hostingView
        
        positionWindow(panel, on: screen)
    }

    private func makeTextView(text: String) -> CenterTextView {
        CenterTextView(text: text, width: windowWidth, playbackSpeed: playbackSpeed, isPlaying: isPlaying, pageInterval: 1.0 / max(playbackSpeed, 0.001), onHide: hideAction, onPlayback: playbackAction, onSlower: slowerAction, onFaster: fasterAction, onSpeed: speedAction, onPrevious: previousAction, onNext: nextAction, onOverview: overviewAction)
    }
    
    private func positionWindow(_ window: NSPanel, on screen: NSScreen) {
        let screenFrame = screen.frame
        let windowHeight = Self.panelHeight

        // Keep the reader clear of Finder windows and the desktop edge for screenshots.
        let x = screenFrame.origin.x + (screenFrame.width / 2) - (windowWidth / 2)
        let y = screenFrame.maxY - windowHeight - 300
        
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
    @State private var highlightStart = Date()
    let text: String
    let width: CGFloat
    let playbackSpeed: Double
    let isPlaying: Bool
    let pageInterval: TimeInterval
    let onHide: (() -> Void)?
    let onPlayback: (() -> Void)?
    let onSlower: (() -> Void)?
    let onFaster: (() -> Void)?
    let onSpeed: ((Double) -> Void)?
    let onPrevious: (() -> Void)?
    let onNext: (() -> Void)?
    let onOverview: (() -> Void)?

    private var textFontSize: CGFloat {
        switch text.count {
        case 0...36: return 30
        case 37...52: return 25
        default: return 21
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                Button("×") { onHide?() }
                Button("‹") { onPrevious?() }
                Button("▶") { onPlayback?() }
                Button("›") { onNext?() }
                Button("⤢") { onOverview?() }
            }

            HStack(spacing: 18) {
                Menu(String(format: "%.3gx", playbackSpeed)) {
                    ForEach([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.75, 2.0], id: \.self) { speed in
                        Button(String(format: "%.2gx", speed)) { onSpeed?(speed) }
                    }
                }
                .menuStyle(.borderlessButton)
                Button("‹") { onSlower?() }
                Text("倍速")
                    .frame(minWidth: 42)
                Button("›") { onFaster?() }
                Button("慢") { onSlower?() }
                Button("快") { onFaster?() }
            }
            .buttonStyle(.borderless)
            .foregroundColor(.white.opacity(0.75))
            .font(.system(size: 18, weight: .medium))
            .buttonStyle(.borderless)
            .foregroundColor(.white.opacity(0.85))

            HStack(spacing: 10) {
            TimelineView(.animation(minimumInterval: 0.03)) { context in
                highlightedText(at: context.date)
                    .font(.system(size: textFontSize, weight: .regular))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            }
        }
        .frame(width: width - 24, height: 160)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onChange(of: text) { _ in
            highlightStart = Date()
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                highlightStart = Date()
            }
        }
    }

    private func highlightedText(at date: Date) -> Text {
        let characters = Array(text)
        guard isPlaying, !characters.isEmpty else {
            return Text(text).foregroundColor(.white)
        }
        let progress = min(max(date.timeIntervalSince(highlightStart) / pageInterval, 0), 1)
        let count = Int(Double(characters.count) * progress)
        let done = String(characters.prefix(count))
        let remaining = String(characters.dropFirst(count))
        return Text(done).foregroundColor(.mint) + Text(remaining).foregroundColor(.white)
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
