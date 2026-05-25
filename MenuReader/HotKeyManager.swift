import HotKey

@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hideHotKey: HotKey?
    private var pauseHotKey: HotKey?
    private var nextBookHotKey: HotKey?
    private var previousBookHotKey: HotKey?
    private var nextPageHotKey: HotKey?
    private var previousPageHotKey: HotKey?

    private init() {}

    func setup(store: ReaderStore) {
        hideHotKey = HotKey(key: .o, modifiers: [.option, .control])
        hideHotKey?.keyDownHandler = { store.toggleVisibility() }

        pauseHotKey = HotKey(key: .p, modifiers: [.option, .control])
        pauseHotKey?.keyDownHandler = { store.togglePlayback() }

        previousBookHotKey = HotKey(key: .k, modifiers: [.option, .control])
        previousBookHotKey?.keyDownHandler = { store.previousBook() }

        nextBookHotKey = HotKey(key: .j, modifiers: [.option, .control])
        nextBookHotKey?.keyDownHandler = { store.nextBook() }

        previousPageHotKey = HotKey(key: .h, modifiers: [.option, .control])
        previousPageHotKey?.keyDownHandler = { store.previousPage() }

        nextPageHotKey = HotKey(key: .l, modifiers: [.option, .control])
        nextPageHotKey?.keyDownHandler = { store.nextPage() }
    }
}
