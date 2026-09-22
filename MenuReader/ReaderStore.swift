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
    @Published private(set) var chapters: [BookChapter] = []
    @Published private(set) var isHidden: Bool = false
    @Published private(set) var pageInterval: TimeInterval = 1.0
    @Published var displayMode: DisplayMode = .right {
        didSet {
            guard isInitialized else { return }
            UserDefaults.standard.set(displayMode.rawValue, forKey: UserDefaultsKey.displayMode)
            syncCenterWindow()
        }
    }
    @Published var pageSize: Int = 20 {
        didSet {
            guard isInitialized else { return }
            UserDefaults.standard.set(pageSize, forKey: UserDefaultsKey.pageSize)
            reloadWithNewPageSize()
        }
    }
    /// Empty set means "all screens". Otherwise contains display IDs of selected screens.
    @Published var selectedScreenIDs: Set<String> = [] {
        didSet {
            guard isInitialized else { return }
            let array = Array(selectedScreenIDs)
            UserDefaults.standard.set(array, forKey: UserDefaultsKey.selectedScreenIDs)
            CenterDisplayWindow.shared.updateScreens(selectedScreenIDs)
        }
    }

    private var pages: [SlicedPage] = []
    private var timer: Timer?
    private var wasPlayingBeforeHidden: Bool = false
    private var bookSwitchTask: Task<Void, Never>?
    private var persistTask: Task<Void, Never>?
    private var isInitialized = false

    var hasPages: Bool { !pages.isEmpty }
    var currentPageIndex: Int { currentPage }
    var pageCount: Int { pages.count }

    func pagePreview(at index: Int) -> String {
        guard pages.indices.contains(index) else { return "" }
        return pages[index].text
    }

    func jumpToPage(_ index: Int, startPlayback shouldStartPlayback: Bool = false) {
        guard pages.indices.contains(index) else { return }
        currentPage = index
        updateDisplay()
        saveCurrentProgress()
        if shouldStartPlayback && !isPlaying { startPlayback() }
    }
    
    func isScreenSelected(_ screenID: String) -> Bool {
        selectedScreenIDs.isEmpty || selectedScreenIDs.contains(screenID)
    }
    
    func toggleScreen(_ screenID: String) {
        if selectedScreenIDs.isEmpty {
            // "All" → switch to only selecting everything except this one
            let allIDs = Set(NSScreen.screens.compactMap { $0.displayUUID })
            selectedScreenIDs = allIDs.subtracting([screenID])
        } else if selectedScreenIDs.contains(screenID) {
            selectedScreenIDs.remove(screenID)
            // If nothing selected, revert to "all"
            if selectedScreenIDs.isEmpty {
                // Keep at least the deselected one off — actually this means user deselected all
                // Revert to all screens
                selectedScreenIDs = []
            }
        } else {
            selectedScreenIDs.insert(screenID)
            // If all screens are now selected, revert to empty (meaning "all")
            let allIDs = Set(NSScreen.screens.compactMap { $0.displayUUID })
            if selectedScreenIDs == allIDs {
                selectedScreenIDs = []
            }
        }
    }
    
    func flushPendingPersist() {
        persistTask?.cancel()
        persistTask = nil
        ReaderStorage.saveLibrary(.init(books: books, currentBookIndex: currentBookIndex))
    }

    var currentBookName: String {
        guard books.indices.contains(currentBookIndex) else { return "无书籍" }
        return books[currentBookIndex].name
    }

    init() {
        let modeString = UserDefaults.standard.string(forKey: UserDefaultsKey.displayMode) ?? DisplayMode.right.rawValue
        displayMode = DisplayMode(rawValue: modeString) ?? .right
        pageSize = UserDefaults.standard.integer(forKey: UserDefaultsKey.pageSize)
        pageInterval = max(UserDefaults.standard.double(forKey: UserDefaultsKey.pageInterval), 0.1)
        CenterDisplayWindow.shared.setDisplayedSpeed(1.0 / pageInterval)
        
        let savedScreenIDs = UserDefaults.standard.stringArray(forKey: UserDefaultsKey.selectedScreenIDs) ?? []
        let currentScreenIDs = Set(NSScreen.screens.compactMap { $0.displayUUID })
        selectedScreenIDs = Set(savedScreenIDs).intersection(currentScreenIDs)
        
        let library = ReaderStorage.loadLibrary()
        books = library.books
        currentBookIndex = library.currentBookIndex

        if books.indices.contains(currentBookIndex) {
            loadCurrentBook()
        }
        isInitialized = true
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
            refreshBookMetadata(for: newBooks)
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
            try? await Task.sleep(nanoseconds: ReaderConstants.bookSwitchDelay)
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

    func jumpToChapter(_ chapter: BookChapter) {
        guard !pages.isEmpty else { return }
        currentPage = PageSlicer.pageIndex(forCharacterOffset: chapter.characterOffset, in: pages)
        updateDisplay()
        saveCurrentProgress()
    }

    func togglePlayback() {
        guard !isHidden else { return }
        isPlaying ? stopPlayback() : startPlayback()
    }

    func setInterval(_ interval: TimeInterval) {
        pageInterval = interval
        UserDefaults.standard.set(interval, forKey: UserDefaultsKey.pageInterval)
        if isPlaying {
            restartPlaybackTimer()
        }
    }

    func slowerPlayback() {
        setPlaybackSpeed(max(playbackSpeed / 2, 0.001))
    }

    func fasterPlayback() {
        setPlaybackSpeed(min(playbackSpeed * 2, 16))
    }

    private var playbackSpeed: Double { 1.0 / pageInterval }

    func setPlaybackSpeed(_ speed: Double) {
        let clampedSpeed = min(max(speed, 0.001), 16)
        setInterval(1.0 / clampedSpeed)
        CenterDisplayWindow.shared.setDisplayedSpeed(clampedSpeed)
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

    func showCurrentReadingWindow() {
        isHidden = false
        syncCenterWindow()
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
            chapters = Self.findChapters(in: text)
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

    private static func findChapters(in text: String) -> [BookChapter] {
        var result: [BookChapter] = []
        var offset = 0
        for line in text.split(whereSeparator: \.isNewline) {
            let title = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let isChapter = title.range(of: "^(序章|楔子|番外|引子|后记|尾声|第.{1,12}(章|节|回|卷))", options: .regularExpression) != nil
            if isChapter && title.count <= 40 {
                result.append(BookChapter(title: title, characterOffset: offset))
            }
            offset += line.count + 1
        }
        return result
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
        CenterDisplayWindow.shared.setPlaybackState(true)
    }

    private func stopPlayback() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
        CenterDisplayWindow.shared.setPlaybackState(false)
    }

    private func restartPlaybackTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pageInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
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
    
    private func refreshBookMetadata(for newBooks: [Book]) {
        for book in newBooks {
            guard let index = books.firstIndex(where: { $0.id == book.id }) else { continue }
            if let text = try? TextBookLoader.loadText(from: books[index].path) {
                let sliced = PageSlicer.slice(content: text, pageSize: pageSize)
                books[index].totalPages = sliced.count
                books[index].currentPage = PageSlicer.pageIndex(
                    forCharacterOffset: books[index].characterOffset, in: sliced
                )
            }
        }
    }

    private func persistLibrary(immediate: Bool = false) {
        persistTask?.cancel()
        if immediate {
            persistTask = nil
            ReaderStorage.saveLibrary(.init(books: books, currentBookIndex: currentBookIndex))
            return
        }
        persistTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: ReaderConstants.persistDebounceDelay)
            guard !Task.isCancelled else { return }
            self.persistTask = nil
            ReaderStorage.saveLibrary(.init(books: self.books, currentBookIndex: self.currentBookIndex))
        }
    }
}
