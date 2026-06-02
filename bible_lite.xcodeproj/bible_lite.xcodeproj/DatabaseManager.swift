import Foundation
import SQLite3

// MARK: - Models

struct Book: Identifiable {
    let id: Int            // 1–66, canonical order
    let name: String
    let testament: String  // "OT" or "NT"
    let chapterCount: Int

    var isOldTestament: Bool { testament == "OT" }
}

struct Verse: Identifiable {
    let id: Int            // verse_id in DB
    let bookId: Int
    let chapter: Int
    let verse: Int
    let text: String

    func reference(bookName: String) -> String { "\(bookName) \(chapter):\(verse)" }
}

struct VerseWord: Identifiable {
    let id: Int            // word_id in DB
    let verseId: Int
    let position: Int
    let word: String       // original language word
    let strongsId: String?
    let grammar: String?
}

struct StrongsEntry {
    let strongsId: String
    let language: String   // "greek" or "hebrew"
    let lemma: String?
    let transliteration: String?
    let pronunciation: String?
    let definition: String?
    let partOfSpeech: String?
}

// MARK: - DatabaseManager

/// Provides read-only access to the bundled bible.sqlite database.
final class DatabaseManager {

    static let shared = DatabaseManager()

    private var db: OpaquePointer?

    private init() { openDatabase() }

    deinit { sqlite3_close(db) }

    // MARK: - Setup

    /// Resolves the writable database path in the app's Documents directory.
    private var documentsDatabasePath: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("bible.sqlite").path
    }

    private func openDatabase() {
        let writablePath = documentsDatabasePath

        // Copy bundled DB to Documents on first launch
        if !FileManager.default.fileExists(atPath: writablePath) {
            guard let bundlePath = Bundle.main.path(forResource: "bible", ofType: "sqlite") else {
                print("[DB] bible.sqlite not found in bundle")
                return
            }
            do {
                try FileManager.default.copyItem(atPath: bundlePath, toPath: writablePath)
            } catch {
                print("[DB] Failed to copy database to Documents: \(error)")
                return
            }
        }

        // Open read-write from Documents so highlights/notes/bookmarks can be saved
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        guard sqlite3_open_v2(writablePath, &db, flags, nil) == SQLITE_OK else {
            print("[DB] Failed to open: \(String(cString: sqlite3_errmsg(db)))")
            db = nil
            return
        }
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("[DB] prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        return stmt
    }

    // MARK: - Books

    func allBooks() -> [Book] {
        guard let stmt = prepare(
            "SELECT book_id, name, testament, chapter_count FROM books ORDER BY book_id"
        ) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var books: [Book] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            books.append(Book(
                id:           Int(sqlite3_column_int(stmt, 0)),
                name:         String(cString: sqlite3_column_text(stmt, 1)),
                testament:    String(cString: sqlite3_column_text(stmt, 2)),
                chapterCount: Int(sqlite3_column_int(stmt, 3))
            ))
        }
        return books
    }

    func book(id: Int) -> Book? {
        guard let stmt = prepare(
            "SELECT book_id, name, testament, chapter_count FROM books WHERE book_id = ? LIMIT 1"
        ) else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(id))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Book(
            id:           Int(sqlite3_column_int(stmt, 0)),
            name:         String(cString: sqlite3_column_text(stmt, 1)),
            testament:    String(cString: sqlite3_column_text(stmt, 2)),
            chapterCount: Int(sqlite3_column_int(stmt, 3))
        )
    }

    // MARK: - Verses

    func verses(bookId: Int, chapter: Int) -> [Verse] {
        guard let stmt = prepare("""
            SELECT verse_id, book_id, chapter, verse, text
            FROM verses WHERE book_id = ? AND chapter = ?
            ORDER BY verse
            """) else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(bookId))
        sqlite3_bind_int(stmt, 2, Int32(chapter))

        var results: [Verse] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(Verse(
                id:      Int(sqlite3_column_int(stmt, 0)),
                bookId:  Int(sqlite3_column_int(stmt, 1)),
                chapter: Int(sqlite3_column_int(stmt, 2)),
                verse:   Int(sqlite3_column_int(stmt, 3)),
                text:    String(cString: sqlite3_column_text(stmt, 4))
            ))
        }
        return results
    }

    func verse(bookId: Int, chapter: Int, verse: Int) -> Verse? {
        guard let stmt = prepare("""
            SELECT verse_id, book_id, chapter, verse, text
            FROM verses WHERE book_id = ? AND chapter = ? AND verse = ?
            LIMIT 1
            """) else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(bookId))
        sqlite3_bind_int(stmt, 2, Int32(chapter))
        sqlite3_bind_int(stmt, 3, Int32(verse))

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Verse(
            id:      Int(sqlite3_column_int(stmt, 0)),
            bookId:  Int(sqlite3_column_int(stmt, 1)),
            chapter: Int(sqlite3_column_int(stmt, 2)),
            verse:   Int(sqlite3_column_int(stmt, 3)),
            text:    String(cString: sqlite3_column_text(stmt, 4))
        )
    }

    // MARK: - Full-text search

    func search(_ query: String, limit: Int = 50) -> [Verse] {
        guard let stmt = prepare("""
            SELECT v.verse_id, v.book_id, v.chapter, v.verse, v.text
            FROM verses_fts
            JOIN verses v ON verses_fts.rowid = v.verse_id
            WHERE verses_fts MATCH ?
            ORDER BY rank LIMIT ?
            """) else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (query as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var results: [Verse] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(Verse(
                id:      Int(sqlite3_column_int(stmt, 0)),
                bookId:  Int(sqlite3_column_int(stmt, 1)),
                chapter: Int(sqlite3_column_int(stmt, 2)),
                verse:   Int(sqlite3_column_int(stmt, 3)),
                text:    String(cString: sqlite3_column_text(stmt, 4))
            ))
        }
        return results
    }

    // MARK: - Word-level data (Strong's)

    func words(forVerseId verseId: Int) -> [VerseWord] {
        guard let stmt = prepare("""
            SELECT word_id, verse_id, position, word, strongs_id, grammar
            FROM verse_words WHERE verse_id = ?
            ORDER BY position
            """) else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(verseId))

        var results: [VerseWord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(VerseWord(
                id:        Int(sqlite3_column_int(stmt, 0)),
                verseId:   Int(sqlite3_column_int(stmt, 1)),
                position:  Int(sqlite3_column_int(stmt, 2)),
                word:      String(cString: sqlite3_column_text(stmt, 3)),
                strongsId: sqlite3_column_text(stmt, 4).map { String(cString: $0) },
                grammar:   sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            ))
        }
        return results
    }

    // MARK: - Strong's concordance

    func strongs(id: String) -> StrongsEntry? {
        guard let stmt = prepare("""
            SELECT strongs_id, language, lemma, transliteration, pronunciation,
                   definition, part_of_speech
            FROM strongs WHERE strongs_id = ? LIMIT 1
            """) else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        return StrongsEntry(
            strongsId:       String(cString: sqlite3_column_text(stmt, 0)),
            language:        String(cString: sqlite3_column_text(stmt, 1)),
            lemma:           sqlite3_column_text(stmt, 2).map { String(cString: $0) },
            transliteration: sqlite3_column_text(stmt, 3).map { String(cString: $0) },
            pronunciation:   sqlite3_column_text(stmt, 4).map { String(cString: $0) },
            definition:      sqlite3_column_text(stmt, 5).map { String(cString: $0) },
            partOfSpeech:    sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        )
    }

    // MARK: - Highlights

    /// Save or replace a highlight for a verse.
    func saveHighlight(verseId: Int, color: String) {
        guard let stmt = prepare("""
            INSERT INTO highlights (verse_id, color)
            VALUES (?, ?)
            ON CONFLICT(verse_id) DO UPDATE SET color = excluded.color,
                created_at = datetime('now')
            """) else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(verseId))
        sqlite3_bind_text(stmt, 2, (color as NSString).utf8String, -1, nil)
        sqlite3_step(stmt)
    }

    /// Remove a highlight for a verse.
    func removeHighlight(verseId: Int) {
        guard let stmt = prepare(
            "DELETE FROM highlights WHERE verse_id = ?"
        ) else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(verseId))
        sqlite3_step(stmt)
    }

    /// Returns the highlight color string for a verse, or nil if not highlighted.
    func highlightColor(forVerseId verseId: Int) -> String? {
        guard let stmt = prepare(
            "SELECT color FROM highlights WHERE verse_id = ? LIMIT 1"
        ) else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(verseId))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return sqlite3_column_text(stmt, 0).map { String(cString: $0) }
    }

    /// Returns a dictionary of [verseId: colorString] for all highlights.
    func allHighlights() -> [Int: String] {
        guard let stmt = prepare(
            "SELECT verse_id, color FROM highlights"
        ) else { return [:] }
        defer { sqlite3_finalize(stmt) }
        var result: [Int: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let verseId = Int(sqlite3_column_int(stmt, 0))
            let color   = String(cString: sqlite3_column_text(stmt, 1))
            result[verseId] = color
        }
        return result
    }

    // MARK: - Convenience

    func chapterCount(bookId: Int) -> Int {
        guard let stmt = prepare(
            "SELECT chapter_count FROM books WHERE book_id = ? LIMIT 1"
        ) else { return 0 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(bookId))
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }

    func verseCount(bookId: Int, chapter: Int) -> Int {
        guard let stmt = prepare(
            "SELECT COUNT(*) FROM verses WHERE book_id = ? AND chapter = ?"
        ) else { return 0 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(bookId))
        sqlite3_bind_int(stmt, 2, Int32(chapter))
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }
}
