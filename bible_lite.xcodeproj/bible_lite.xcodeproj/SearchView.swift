import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [Verse] = []
    @State private var isSearching = false
    @State private var referenceNavTarget: BibleReference?
    @State private var navigateToReference = false

    private let db = DatabaseManager.shared
    private let books: [Int: Book]
    private let allBooksList: [Book]

    init() {
        var map: [Int: Book] = [:]
        let list = DatabaseManager.shared.allBooks()
        for book in list { map[book.id] = book }
        books = map
        allBooksList = list
    }

    // Computed suggestion state
    private var parsedReference: BibleReference? { BibleReferenceParser.parse(query) }
    private var bookSuggestions: [String] { BibleReferenceParser.suggestions(for: query) }
    private var showSuggestions: Bool { !query.isEmpty && (!bookSuggestions.isEmpty || parsedReference != nil) }

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    emptyPrompt
                } else if isSearching {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty && !showSuggestions {
                    ContentUnavailableView.search(text: query)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if showSuggestions { suggestionsSection }
                            if !results.isEmpty { resultsSection }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search or type a reference (e.g. Jn 3:16)")
            .onChange(of: query) { _, newValue in performSearch(newValue) }
            .navigationDestination(isPresented: $navigateToReference) {
                referenceDestination()
            }
        }
    }

    // MARK: - Suggestions section

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Direct reference navigation row
            if let ref = parsedReference {
                Button {
                    referenceNavTarget = ref
                    navigateToReference = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Go to \(ref.displayString)")
                                .font(.subheadline.bold())
                            Text(ref.verse != nil ? "Open verse" :
                                 ref.chapter != nil ? "Open chapter" : "Open book")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                }
                .buttonStyle(.plain)
            }

            // Book suggestion chips
            if !bookSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(bookSuggestions, id: \.self) { name in
                            Button {
                                query = name
                            } label: {
                                Text(name)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                                    .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            if !results.isEmpty {
                Divider().padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Results section

    private var resultsSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(results) { verse in
                NavigationLink(destination: VerseDetailView(
                    verse: verse,
                    bookName: books[verse.bookId]?.name ?? ""
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(referenceLabel(for: verse))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(highlightedText(verse.text, query: query))
                            .font(.body)
                            .lineLimit(3)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                Divider().padding(.horizontal)
            }
        }
    }

    // MARK: - Reference destination

    @ViewBuilder
    private func referenceDestination() -> some View {
        if let ref = referenceNavTarget {
            if let v = ref.verse, let ch = ref.chapter,
               let verse = DatabaseManager.shared.verse(bookId: ref.bookId, chapter: ch, verse: v) {
                VerseStudyView(verse: verse, bookName: ref.bookName)
            } else if let ch = ref.chapter,
                      let book = allBooksList.first(where: { $0.id == ref.bookId }) {
                VerseListView(book: book, chapter: ch)
            } else if let book = allBooksList.first(where: { $0.id == ref.bookId }) {
                ChapterListView(book: book)
            } else {
                Text("Not found")
            }
        }
    }
}

extension SearchView {
    // MARK: - Empty prompt

    var emptyPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Search all 31,102 verses")
                .font(.headline)
            Text("Try \"faith\", \"love one another\", or \"in the beginning\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    func referenceLabel(for verse: Verse) -> String {
        let bookName = books[verse.bookId]?.name ?? "Book \(verse.bookId)"
        return "\(bookName) \(verse.chapter):\(verse.verse)"
    }

    /// Wraps query terms in bold using AttributedString for highlighting.
    private func highlightedText(_ text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        let terms = query.split(separator: " ").map(String.init)
        for term in terms {
            var searchRange = attributed.startIndex..<attributed.endIndex
            while let range = attributed[searchRange].range(of: term, options: [.caseInsensitive]) {
                attributed[range].font = .body.bold()
                attributed[range].foregroundColor = .accentColor
                searchRange = range.upperBound..<attributed.endIndex
            }
        }
        return attributed
    }

    private func performSearch(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            return
        }

        isSearching = true
        Task.detached(priority: .userInitiated) { [trimmed] in
            let found = await Task { DatabaseManager.shared.search(trimmed, limit: 100) }.value
            await MainActor.run {
                results = found
                isSearching = false
            }
        }
    }
}

// MARK: - Verse Detail View

struct VerseDetailView: View {
    let verse: Verse
    let bookName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(bookName) \(verse.chapter):\(verse.verse)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(verse.text)
                    .font(.title3)
                    .lineSpacing(6)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("\(bookName) \(verse.chapter):\(verse.verse)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SearchView()
}
