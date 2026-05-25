import Foundation

enum ReaderOptions {
    static let pageSizes: [Int] = [10, 20, 30, 40, 50, 60]
    static let intervals: [TimeInterval] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
}

enum CenterOverlapMode: String {
    case overlay = "overlay"    // 文字覆盖在图标上层
    case below = "below"        // 文字下移到菜单栏下方
}

struct Book: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let path: String
    var currentPage: Int
    var totalPages: Int
    var characterOffset: Int
    
    init(id: UUID = UUID(), name: String, path: String, currentPage: Int = 0, totalPages: Int = 0, characterOffset: Int = 0) {
        self.id = id
        self.name = name
        self.path = path
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.characterOffset = characterOffset
    }
}

struct ReaderLibrary: Codable {
    var books: [Book]
    var currentBookIndex: Int
}
