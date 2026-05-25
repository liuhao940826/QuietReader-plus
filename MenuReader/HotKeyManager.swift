import AppKit
import KeyboardShortcuts

@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()
    
    private weak var store: ReaderStore?

    private init() {}

    func setup(store: ReaderStore) {
        self.store = store
        
        // Register all shortcuts using onKeyUp
        KeyboardShortcuts.onKeyUp(for: .toggleVisibility) { [weak store] in
            store?.toggleVisibility()
        }
        
        KeyboardShortcuts.onKeyUp(for: .togglePlayback) { [weak store] in
            store?.togglePlayback()
        }
        
        KeyboardShortcuts.onKeyUp(for: .previousPage) { [weak store] in
            store?.previousPage()
        }
        
        KeyboardShortcuts.onKeyUp(for: .nextPage) { [weak store] in
            store?.nextPage()
        }
        
        KeyboardShortcuts.onKeyUp(for: .previousBook) { [weak store] in
            store?.previousBook()
        }
        
        KeyboardShortcuts.onKeyUp(for: .nextBook) { [weak store] in
            store?.nextBook()
        }
    }
}
