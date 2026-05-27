import Foundation

enum ReaderStorage {
    private static let libraryKey = UserDefaultsKey.library

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
        do {
            let data = try JSONEncoder().encode(library)
            UserDefaults.standard.set(data, forKey: libraryKey)
        } catch {
            print("[MenuReader] Failed to save library: \(error.localizedDescription)")
        }
    }
}


enum TextBookLoader {
    static func loadText(from path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let text = try? String(contentsOf: url, encoding: gb18030) { return text }
        return try String(contentsOf: url, encoding: .utf8)
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
    static let defaultPageSize = ReaderConstants.defaultPageSize

    private static let preferredBreakCharacters: Set<Character> = [
        "。", "！", "？", "；", "：", "，", "、", ".", ",", "!", "?", ";", ":", " ", "\n"
    ]

    static func slice(content: String, pageSize: Int = defaultPageSize) -> [SlicedPage] {
        let effectivePageSize = max(pageSize, 1)
        let normalized = ReaderTextPipeline.normalize(content)
        let characters = Array(normalized)

        guard !characters.isEmpty else { return [] }

        var pages: [SlicedPage] = []
        var cursor = 0

        while cursor < characters.count {
            let hardEnd = min(cursor + effectivePageSize, characters.count)
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

        let searchStart = max(start + 1, hardEnd - ReaderConstants.breakSearchRange)
        let preferred = stride(from: hardEnd, through: searchStart, by: -1).first { index in
            preferredBreakCharacters.contains(characters[index - 1])
        }

        var end = preferred ?? hardEnd
        
        // Extend to include any no-start characters that would appear at next page start
        while end < characters.count, noStartCharacters.contains(characters[end]) {
            end += 1
        }

        return end
    }

    private static let noStartCharacters: Set<Character> = [
        // 句末/句中标点
        "。", "！", "？", "；", "：", "，", "、",
        ".", ",", "!", "?", ";", ":",
        // 闭合括号/引号
        "）", "」", "』", "》", "】", "〉",
        ")", "]", "}",
        "\u{201D}", "\u{2019}", // " '（闭合弯引号）
        // 省略号
        "…"
    ]
    
    private static func advanceCursor(after index: Int, in characters: [Character]) -> Int {
        var cursor = index
        while cursor < characters.count, characters[cursor].isWhitespace {
            cursor += 1
        }
        return cursor
    }
}
