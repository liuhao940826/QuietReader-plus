import Foundation

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
