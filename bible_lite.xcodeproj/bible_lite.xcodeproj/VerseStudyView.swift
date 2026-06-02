import SwiftUI

// MARK: - Verse Study View

struct VerseStudyView: View {
    let verse: Verse
    let bookName: String

    @State private var words: [VerseWord] = []
    @State private var selectedWord: VerseWord?
    @State private var selectedStrongs: StrongsEntry?
    @State private var showStrongsSheet = false
    @StateObject private var highlightsManager = HighlightsManager.shared

    private var reference: String { "\(bookName) \(verse.chapter):\(verse.verse)" }
    private var isNT: Bool { verse.bookId >= 40 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // ── English verse ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text(reference)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(verse.text)
                        .font(.title3)
                        .lineSpacing(6)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            highlightsManager.color(forVerseId: verse.id).map { $0.color }
                            ?? Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                }

                Divider()

                // ── Original language words ────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        isNT ? "Greek (Textus Receptus)" : "Hebrew (Morphological)",
                        systemImage: isNT ? "character.book.closed.el" : "character.book.closed.he"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                    if words.isEmpty {
                        Text("No word data available for this verse.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        WordChipsGrid(
                            words: words,
                            onTap: { word in
                                selectedWord = word
                                if let sid = word.strongsId {
                                    selectedStrongs = DatabaseManager.shared.strongs(id: sid)
                                } else {
                                    selectedStrongs = nil
                                }
                                showStrongsSheet = true
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle(reference)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            words = DatabaseManager.shared.words(forVerseId: verse.id)
        }
        .sheet(isPresented: $showStrongsSheet) {
            if let word = selectedWord {
                StrongsDetailSheet(word: word, entry: selectedStrongs)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Word Chips Grid

/// Lays out word chips in a wrapping flow layout.
struct WordChipsGrid: View {
    let words: [VerseWord]
    let onTap: (VerseWord) -> Void

    var body: some View {
        // Use a wrapping HStack via ViewThatFits + lazy grid approach
        FlowLayout(spacing: 8) {
            ForEach(words) { word in
                WordChip(word: word, onTap: onTap)
            }
        }
    }
}

// MARK: - Word Chip

private struct WordChip: View {
    let word: VerseWord
    let onTap: (VerseWord) -> Void

    var body: some View {
        Button { onTap(word) } label: {
            VStack(spacing: 2) {
                Text(word.word)
                    .font(.system(.body, design: .default))
                if let sid = word.strongsId {
                    Text(sid)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(word.strongsId != nil
                          ? Color.accentColor.opacity(0.12)
                          : Color(.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(word.strongsId != nil ? 0.3 : 0.1),
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

/// Simple wrapping layout for word chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.maxHeight } + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for subview in row.subviews {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.maxHeight + spacing
        }
    }

    private struct Row {
        var subviews: [LayoutSubview] = []
        var maxHeight: CGFloat = 0
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var currentRow = Row()
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !currentRow.subviews.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
                currentWidth = 0
            }
            currentRow.subviews.append(subview)
            currentRow.maxHeight = max(currentRow.maxHeight, size.height)
            currentWidth += size.width + spacing
        }
        if !currentRow.subviews.isEmpty { rows.append(currentRow) }
        return rows
    }
}

// MARK: - Strong's Detail Sheet

struct StrongsDetailSheet: View {
    let word: VerseWord
    let entry: StrongsEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Word header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word.word)
                            .font(.largeTitle.bold())
                        HStack(spacing: 12) {
                            if let sid = word.strongsId {
                                Label(sid, systemImage: "number")
                                    .font(.subheadline.monospaced())
                                    .foregroundStyle(Color.accentColor)
                            }
                            if let grammar = word.grammar {
                                Label(grammar, systemImage: "text.justify.left")
                                    .font(.subheadline.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    if let entry {
                        // Lemma + transliteration
                        if let lemma = entry.lemma {
                            StrongsRow(label: "Original", value: lemma)
                        }
                        if let xlit = entry.transliteration {
                            StrongsRow(label: "Transliteration", value: xlit)
                        }
                        if let pron = entry.pronunciation {
                            StrongsRow(label: "Pronunciation", value: pron)
                        }
                        if let pos = entry.partOfSpeech {
                            StrongsRow(label: "Part of speech", value: pos)
                        }

                        Divider()

                        // Definition
                        if let def = entry.definition {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Definition")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Text(def)
                                    .font(.body)
                                    .lineSpacing(4)
                            }
                        }

                        // Language badge
                        HStack {
                            Spacer()
                            Text(entry.language.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(Color.accentColor.opacity(0.12))
                                )
                        }
                        .padding(.top, 4)

                    } else {
                        Text(word.strongsId == nil
                             ? "No Strong's number for this word."
                             : "No concordance entry found for \(word.strongsId ?? "").")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Strong's")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct StrongsRow: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack {
        VerseStudyView(
            verse: Verse(id: 1, bookId: 43, chapter: 3, verse: 16,
                         text: "For God so loved the world..."),
            bookName: "John"
        )
    }
}
