import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleVisibility = Self("toggleVisibility", default: .init(.o, modifiers: [.option, .control]))
    static let togglePlayback = Self("togglePlayback", default: .init(.p, modifiers: [.option, .control]))
    static let previousPage = Self("previousPage", default: .init(.h, modifiers: [.option, .control]))
    static let nextPage = Self("nextPage", default: .init(.l, modifiers: [.option, .control]))
    static let previousBook = Self("previousBook", default: .init(.k, modifiers: [.option, .control]))
    static let nextBook = Self("nextBook", default: .init(.j, modifiers: [.option, .control]))
}
