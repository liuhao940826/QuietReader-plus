import AppKit
import Foundation
import UniformTypeIdentifiers

enum ReaderStorage {
    private static let libraryKey = "reader.library"

    static func loadLibrary() -> ReaderLibrary {
        guard
            let data = UserDefaults.standard.data(forKey: libraryKey),
            let library = try? JSONDecoder().decode(ReaderLibrary.self, from: data)
        else {
            return ReaderLibrary(books: [], currentBookIndex: 0)
        }

        let existingBooks = library.books.filter { FileManager.default.fileExists(atPath: $0.path) }
        let boundedIndex = min(max(library.currentBookIndex, 0), max(existingBooks.count - 1, 0))
        return ReaderLibrary(books: existingBooks, currentBookIndex: boundedIndex)
    }

    static func saveLibrary(_ library: ReaderLibrary) {
        guard let data = try? JSONEncoder().encode(library) else { return }
        UserDefaults.standard.set(data, forKey: libraryKey)
    }
}

enum TextBookImporter {
    static func selectFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        return panel.runModal() == .OK ? panel.urls : []
    }
}

enum TextBookLoader {
    static func loadText(from path: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
    }
}

enum ReaderTextPipeline {
    static func normalize(_ content: String) -> String {
        let unifiedLines = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\t", with: " ")

        let paragraphs = unifiedLines
            .components(separatedBy: CharacterSet.newlines)
            .map { paragraph in
                paragraph
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }

        return paragraphs.joined(separator: "\n")
    }

    static func menuBarLine(_ content: String) -> String {
        content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SlicedPage {
    let text: String
    let startOffset: Int
    let endOffset: Int
}

enum PageSlicer {
    static let defaultPageSize = 20

    private static let preferredBreakCharacters: Set<Character> = [
        "。", "！", "？", "；", "：", "，", "、", ".", ",", "!", "?", ";", ":", " ", "\n"
    ]

    static func slice(content: String, pageSize: Int = defaultPageSize) -> [SlicedPage] {
        let normalized = ReaderTextPipeline.normalize(content)
        let characters = Array(normalized)

        guard !characters.isEmpty else { return [] }

        var pages: [SlicedPage] = []
        var cursor = 0

        while cursor < characters.count {
            let hardEnd = min(cursor + pageSize, characters.count)
            let sliceEnd = bestBreakIndex(in: characters, start: cursor, hardEnd: hardEnd)
            let rawPage = String(characters[cursor..<sliceEnd])
            let page = rawPage.trimmingCharacters(in: .whitespacesAndNewlines)

            if !page.isEmpty {
                pages.append(SlicedPage(text: page, startOffset: cursor, endOffset: sliceEnd))
            }

            cursor = advanceCursor(after: sliceEnd, in: characters)
        }

        return pages
    }
    
    static func pageIndex(forCharacterOffset offset: Int, in pages: [SlicedPage]) -> Int {
        guard !pages.isEmpty else { return 0 }
        
        for (index, page) in pages.enumerated() {
            if offset <= page.startOffset {
                return index
            }
            if offset < page.endOffset {
                return index
            }
        }
        
        return pages.count - 1
    }

    private static func bestBreakIndex(in characters: [Character], start: Int, hardEnd: Int) -> Int {
        guard hardEnd < characters.count else { return hardEnd }

        let searchStart = max(start + 1, hardEnd - 6)
        let preferred = stride(from: hardEnd, through: searchStart, by: -1).first { index in
            preferredBreakCharacters.contains(characters[index - 1])
        }

        if let preferred {
            return preferred
        }

        return hardEnd
    }

    private static func advanceCursor(after index: Int, in characters: [Character]) -> Int {
        var cursor = index
        while cursor < characters.count, characters[cursor].isWhitespace {
            cursor += 1
        }
        return cursor
    }
}
