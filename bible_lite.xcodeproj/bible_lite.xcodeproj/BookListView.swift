import SwiftUI

// MARK: - Book List

struct BookListView: View {
    private let db = DatabaseManager.shared

    private var oldTestament: [Book] { db.allBooks().filter { $0.isOldTestament } }
    private var newTestament: [Book] { db.allBooks().filter { !$0.isOldTestament } }

    var body: some View {
        NavigationStack {
            List {
                Section("Old Testament") {
                    ForEach(oldTestament) { book in BookRow(book: book) }
                }
                Section("New Testament") {
                    ForEach(newTestament) { book in BookRow(book: book) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Bible")
        }
    }
}

// MARK: - Book Row

private struct BookRow: View {
    let book: Book
    var body: some View {
        NavigationLink(destination: ChapterListView(book: book)) {
            HStack {
                Text(book.name)
                Spacer()
                Text("\(book.chapterCount) ch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Chapter List

struct ChapterListView: View {
    let book: Book
    var body: some View {
        Group {
            if book.chapterCount > 0 {
                List(1...book.chapterCount, id: \.self) { chapter in
                    NavigationLink(destination: VerseListView(book: book, chapter: chapter)) {
                        Text("Chapter \(chapter)")
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView("No chapters found", systemImage: "book.closed")
            }
        }
        .navigationTitle(book.name)
    }
}

// MARK: - Verse List

struct VerseListView: View {
    let book: Book
    let chapter: Int

    @StateObject private var highlightsManager = HighlightsManager.shared
    @State private var selectedVerse: Verse?
    @State private var showColorPicker = false
    @State private var verses: [Verse] = []

    var body: some View {
        List(verses) { verse in
            NavigationLink(destination: VerseStudyView(verse: verse, bookName: book.name)) {
                VerseRow(verse: verse, highlightsManager: highlightsManager)
            }
            .contextMenu {
                Button {
                    selectedVerse = verse
                    showColorPicker = true
                } label: {
                    Label("Highlight", systemImage: "highlighter")
                }
            }
            .simultaneousGesture(
                LongPressGesture().onEnded { _ in
                    selectedVerse = verse
                    showColorPicker = true
                }
            )
        }
        .listStyle(.plain)
        .navigationTitle("\(book.name) \(chapter)")
        .task {
            verses = DatabaseManager.shared.verses(bookId: book.id, chapter: chapter)
        }
        .sheet(isPresented: $showColorPicker) {
            if let verse = selectedVerse {
                HighlightPickerSheet(
                    verse: verse,
                    highlightsManager: highlightsManager,
                    isPresented: $showColorPicker
                )
                .presentationDetents([.height(220)])
            }
        }
    }
}

// MARK: - Verse Row

private struct VerseRow: View {
    let verse: Verse
    @ObservedObject var highlightsManager: HighlightsManager

    var body: some View {
        let highlight = highlightsManager.color(forVerseId: verse.id)
        HStack(spacing: 0) {
            // Colored left border when highlighted
            if let h = highlight {
                Rectangle()
                    .fill(h.solidColor)
                    .frame(width: 4)
                    .cornerRadius(2)
                    .padding(.trailing, 10)
            } else {
                Spacer().frame(width: 14)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(verse.verse)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(verse.text)
                    .font(.body)
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(
            highlight.map { $0.color } ?? Color(.systemBackground)
        )
    }
}

// MARK: - Highlight Picker Sheet

private struct HighlightPickerSheet: View {
    let verse: Verse
    @ObservedObject var highlightsManager: HighlightsManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Highlight")
                .font(.headline)
                .padding(.top)

            HStack(spacing: 20) {
                ForEach(HighlightColor.allCases) { hc in
                    let isCurrent = highlightsManager.color(forVerseId: verse.id) == hc
                    Button {
                        if isCurrent {
                            highlightsManager.remove(verseId: verse.id)
                        } else {
                            highlightsManager.save(verseId: verse.id, color: hc)
                        }
                        isPresented = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(hc.solidColor)
                                .frame(width: 44, height: 44)
                            if isCurrent {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(Circle().stroke(isCurrent ? Color.primary : Color.clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }

            if highlightsManager.color(forVerseId: verse.id) != nil {
                Button(role: .destructive) {
                    highlightsManager.remove(verseId: verse.id)
                    isPresented = false
                } label: {
                    Label("Remove highlight", systemImage: "trash")
                        .font(.subheadline)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
    }
}

#Preview { BookListView() }
