import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [Verse] = []
    @State private var isSearching = false

    private let db = DatabaseManager.shared
    private let books: [Int: Book]

    init() {
        // Build a bookId → Book lookup so results can show book names
        var map: [Int: Book] = [:]
        for book in DatabaseManager.shared.allBooks() {
            map[book.id] = book
        }
        books = map
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    emptyPrompt
                } else if isSearching {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search the Bible")
            .onChange(of: query) { _, newValue in
                performSearch(newValue)
            }
        }
    }

    // MARK: - Subviews

    private var emptyPrompt: some View {
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

    private var resultsList: some View {
        List(results) { verse in
            NavigationLink(destination: VerseDetailView(verse: verse, bookName: books[verse.bookId]?.name ?? "")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(referenceLabel(for: verse))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(highlightedText(verse.text, query: query))
                        .font(.body)
                        .lineLimit(3)
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if !results.isEmpty {
                Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding()
            }
        }
    }

    // MARK: - Helpers

    private func referenceLabel(for verse: Verse) -> String {
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
        Task.detached(priority: .userInitiated) {
            let found = DatabaseManager.shared.search(trimmed, limit: 100)
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
