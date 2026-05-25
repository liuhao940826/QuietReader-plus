import AppKit
import Foundation

@MainActor
final class ReaderStore: ObservableObject {
    @Published private(set) var currentText: String = "📖 无书籍"
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentPage: Int = 0
    @Published private(set) var totalPages: Int = 0
    @Published private(set) var currentBookIndex: Int = 0
    @Published private(set) var books: [Book] = []
    @Published private(set) var isHidden: Bool = false
    @Published private(set) var pageInterval: TimeInterval = 1.0

    private var pages: [String] = []
    private var timer: Timer?
    private var wasPlayingBeforeHidden: Bool = false

    var hasPages: Bool { !pages.isEmpty }

    var currentBookName: String {
        guard books.indices.contains(currentBookIndex) else { return "无书籍" }
        return books[currentBookIndex].name
    }

    init() {
        let library = ReaderStorage.loadLibrary()
        books = library.books
        currentBookIndex = library.currentBookIndex

        if books.indices.contains(currentBookIndex) {
            loadCurrentBook()
        }
    }

    func addBooks() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else { return }

        let existingPaths = Set(books.map(\.path))
        let newBooks = panel.urls
            .filter { !existingPaths.contains($0.path) }
            .map { Book(name: $0.lastPathComponent, path: $0.path) }

        guard !newBooks.isEmpty else { return }

        let wasEmpty = books.isEmpty
        books.append(contentsOf: newBooks)

        if wasEmpty {
            currentBookIndex = 0
            loadCurrentBook()
        } else {
            refreshBookMetadata()
        }

        persistLibrary()
    }

    func removeBook(at index: Int) {
        guard books.indices.contains(index) else { return }
        books.remove(at: index)

        if books.isEmpty {
            stopPlayback()
            currentBookIndex = 0
            currentPage = 0
            totalPages = 0
            pages = []
            currentText = "📖 无书籍"
            persistLibrary()
            return
        }

        currentBookIndex = min(currentBookIndex, books.count - 1)
        loadCurrentBook()
        persistLibrary()
    }

    func selectBook(at index: Int) {
        guard !isHidden else { return }
        guard books.indices.contains(index), index != currentBookIndex else { return }
        saveCurrentProgress()
        
        let wasPlaying = isPlaying
        stopPlayback()
        currentBookIndex = index
        
        // Show book name for 2 seconds
        currentText = "📖 \(books[currentBookIndex].name)"
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            loadCurrentBook()
            if wasPlaying {
                startPlayback()
            }
        }
        
        persistLibrary()
    }

    func nextBook() {
        guard !isHidden else { return }
        guard !books.isEmpty else { return }
        let nextIndex = (currentBookIndex + 1) % books.count
        selectBook(at: nextIndex)
    }

    func previousBook() {
        guard !isHidden else { return }
        guard !books.isEmpty else { return }
        let nextIndex = (currentBookIndex - 1 + books.count) % books.count
        selectBook(at: nextIndex)
    }

    func nextPage() {
        guard !isHidden else { return }
        guard !pages.isEmpty else { return }
        currentPage = (currentPage + 1) % totalPages
        updateDisplay()
        saveCurrentProgress()
    }

    func previousPage() {
        guard !isHidden else { return }
        guard !pages.isEmpty else { return }
        currentPage = (currentPage - 1 + totalPages) % totalPages
        updateDisplay()
        saveCurrentProgress()
    }

    func togglePlayback() {
        guard !isHidden else { return }
        isPlaying ? stopPlayback() : startPlayback()
    }

    func setInterval(_ interval: TimeInterval) {
        pageInterval = interval
        if isPlaying {
            restartPlaybackTimer()
        }
    }

    func toggleVisibility() {
        isHidden.toggle()
        
        if isHidden {
            wasPlayingBeforeHidden = isPlaying
            stopPlayback()
        } else {
            if wasPlayingBeforeHidden && hasPages {
                startPlayback()
            }
        }
    }

    private func loadCurrentBook() {
        guard books.indices.contains(currentBookIndex) else {
            currentText = "📖 无书籍"
            pages = []
            totalPages = 0
            currentPage = 0
            return
        }

        do {
            let text = try TextBookLoader.loadText(from: books[currentBookIndex].path)
            pages = PageSlicer.slice(content: text)
            totalPages = pages.count
            books[currentBookIndex].totalPages = totalPages
            currentPage = min(max(books[currentBookIndex].currentPage, 0), max(totalPages - 1, 0))
            updateDisplay()
        } catch {
            pages = []
            totalPages = 0
            currentPage = 0
            currentText = "❌ 读取失败"
        }
    }

    private func updateDisplay() {
        guard pages.indices.contains(currentPage) else {
            currentText = books.isEmpty ? "📖 无书籍" : "📖"
            return
        }
        currentText = ReaderTextPipeline.menuBarLine(pages[currentPage])
    }

    private func startPlayback() {
        guard hasPages else { return }
        restartPlaybackTimer()
        isPlaying = true
    }

    private func stopPlayback() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
    }

    private func restartPlaybackTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pageInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.nextPage()
            }
        }
    }

    private func saveCurrentProgress() {
        guard books.indices.contains(currentBookIndex) else { return }
        books[currentBookIndex].currentPage = currentPage
        persistLibrary()
    }

    private func refreshBookMetadata() {
        for index in books.indices {
            if let text = try? TextBookLoader.loadText(from: books[index].path) {
                books[index].totalPages = PageSlicer.slice(content: text).count
            }
        }
    }

    private func persistLibrary() {
        ReaderStorage.saveLibrary(.init(books: books, currentBookIndex: currentBookIndex))
    }
}
