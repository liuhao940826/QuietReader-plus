import Foundation

enum UserDefaultsKey {
    static let library = "reader.library"
    static let displayMode = "displayMode"
    static let pageSize = "pageSize"
    static let pageInterval = "pageInterval"
    static let selectedScreenIDs = "selectedScreenIDs"
    static let launchAtLogin = "launchAtLogin"
}

enum ReaderConstants {
    static let menuBarHeight: CGFloat = 22
    static let bookSwitchDelay: UInt64 = 1_500_000_000
    static let persistDebounceDelay: UInt64 = 2_000_000_000
    static let windowPadding: CGFloat = 8.0
    static let defaultPageSize = 20
    static let breakSearchRange = 6
}
