import Foundation

enum UserDefaultsKey {
    static let library = "reader.library"
    static let displayMode = "reader.displayMode"
    static let pageSize = "reader.pageSize"
    static let pageInterval = "reader.pageInterval"
    static let selectedScreenIDs = "reader.selectedScreenIDs"
    static let launchAtLogin = "reader.launchAtLogin"
}

enum ReaderConstants {
    static let menuBarHeight: CGFloat = 22
    static let bookSwitchDelay: UInt64 = 1_500_000_000
    static let persistDebounceDelay: UInt64 = 2_000_000_000
    static let windowPadding: CGFloat = 8.0
    static let defaultPageSize = 20
    static let breakSearchRange = 6
}
