import AppKit
import Foundation

@MainActor
final class ReaderStore: ObservableObject {
    enum DisplayMode: String {
        case right = "right"
        case center = "center"
    }
    
    @Published private(set) var currentText: String = "📖 无书籍"
    @Published private(set) var isPlaying: Bool = false
    private var currentPage: Int = 0
    private var totalPages: Int = 0
    @Published private(set) var currentBookIndex: Int = 0
    @Published private(set) var books: [Book] = []
    @Published private(set) var isHidden: Bool = false
    @Published private(set) var pageInterval: TimeInterval = 1.0
    @Published var displayMode: DisplayMode = .right {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: "displayMode")
            syncCenterWindow()
        }
    }
    @Published var pageSize: Int = 20 {
        didSet {
            UserDefaults.standard.set(pageSize, forKey: "pageSize")
            reloadWithNewPageSize()
        }
    }

    private var pages: [SlicedPage] = []
    private var timer: Timer?
    private var wasPlayingBeforeHidden: Bool = false
    private var bookSwitchTask: Task<Void, Never>?
    private var persistTask: Task<Void, Never>?

    var hasPages: Bool { !pages.isEmpty }

    var currentBookName: String {
        guard books.indices.contains(currentBookIndex) else { return "无书籍" }
        return books[currentBookIndex].name
    }

    init() {
        if let modeString = UserDefaults.standard.string(forKey: "displayMode"),
           let mode = DisplayMode(rawValue: modeString) {
            displayMode = mode
        }
        
        let savedPageSize = UserDefaults.standard.integer(forKey: "pageSize")
        if savedPageSize > 0 {
            pageSize = savedPageSize
        }
        
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

        persistLibrary(immediate: true)
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
            syncCenterWindow()
            persistLibrary(immediate: true)
            return
        }

        currentBookIndex = min(currentBookIndex, books.count - 1)
        loadCurrentBook()
        persistLibrary(immediate: true)
    }

    func selectBook(at index: Int) {
        guard !isHidden else { return }
        guard books.indices.contains(index), index != currentBookIndex else { return }
        saveCurrentProgress()
        
        let wasPlaying = isPlaying
        stopPlayback()
        currentBookIndex = index
        
        // Show book name for 1.5 seconds
        currentText = "📖 \(books[currentBookIndex].name)"
        syncCenterWindow()
        
        bookSwitchTask?.cancel()
        bookSwitchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            loadCurrentBook()
            if wasPlaying {
                startPlayback()
            }
        }
        
        persistLibrary(immediate: true)
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
        let prevIndex = (currentBookIndex - 1 + books.count) % books.count
        selectBook(at: prevIndex)
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

    func toggleDisplayMode() {
        displayMode = (displayMode == .right) ? .center : .right
    }
    
    func toggleVisibility() {
        isHidden.toggle()
        
        if isHidden {
            wasPlayingBeforeHidden = isPlaying
            stopPlayback()
            CenterDisplayWindow.shared.hide()
        } else {
            if wasPlayingBeforeHidden && hasPages {
                startPlayback()
            }
            syncCenterWindow()
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
            pages = PageSlicer.slice(content: text, pageSize: pageSize)
            totalPages = pages.count
            books[currentBookIndex].totalPages = totalPages
            
            // Restore position from characterOffset
            let offset = books[currentBookIndex].characterOffset
            currentPage = PageSlicer.pageIndex(forCharacterOffset: offset, in: pages)
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
            syncCenterWindow()
            return
        }
        currentText = ReaderTextPipeline.menuBarLine(pages[currentPage].text)
        syncCenterWindow()
    }
    
    private func syncCenterWindow() {
        if displayMode == .center && !isHidden {
            CenterDisplayWindow.shared.show(text: currentText)
        } else {
            CenterDisplayWindow.shared.hide()
        }
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
        if pages.indices.contains(currentPage) {
            books[currentBookIndex].characterOffset = pages[currentPage].startOffset
        }
        persistLibrary()
    }

    private func reloadWithNewPageSize() {
        guard books.indices.contains(currentBookIndex) else { return }
        // Save current offset before re-slicing
        if pages.indices.contains(currentPage) {
            books[currentBookIndex].characterOffset = pages[currentPage].startOffset
        }
        loadCurrentBook()
        CenterDisplayWindow.shared.updateWidth(forPageSize: pageSize)
    }
    
    private func refreshBookMetadata() {
        for index in books.indices {
            if let text = try? TextBookLoader.loadText(from: books[index].path) {
                books[index].totalPages = PageSlicer.slice(content: text, pageSize: pageSize).count
            }
        }
    }

    private func persistLibrary(immediate: Bool = false) {
        if immediate {
            persistTask?.cancel()
            persistTask = nil
            ReaderStorage.saveLibrary(.init(books: books, currentBookIndex: currentBookIndex))
            return
        }
        guard persistTask == nil else { return }
        persistTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self.persistTask = nil
            ReaderStorage.saveLibrary(.init(books: self.books, currentBookIndex: self.currentBookIndex))
        }
    }
}
