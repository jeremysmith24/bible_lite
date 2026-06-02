import XCTest
@testable import bible_lite

final class DatabaseManagerTests: XCTestCase {

    let db = DatabaseManager.shared

    // MARK: - Books

    func testAllBooksReturns66() {
        XCTAssertEqual(db.allBooks().count, 66)
    }

    func testFirstBookIsGenesis() {
        let first = db.allBooks().first
        XCTAssertEqual(first?.id, 1)
        XCTAssertEqual(first?.name, "Genesis")
        XCTAssertEqual(first?.testament, "OT")
    }

    func testLastBookIsRevelation() {
        let last = db.allBooks().last
        XCTAssertEqual(last?.id, 66)
        XCTAssertEqual(last?.name, "Revelation")
        XCTAssertEqual(last?.testament, "NT")
    }

    func testOldTestamentContains39Books() {
        XCTAssertEqual(db.allBooks().filter { $0.isOldTestament }.count, 39)
    }

    func testNewTestamentContains27Books() {
        XCTAssertEqual(db.allBooks().filter { !$0.isOldTestament }.count, 27)
    }

    func testBookLookupById() {
        let john = db.book(id: 43)
        XCTAssertEqual(john?.name, "John")
        XCTAssertEqual(john?.testament, "NT")
    }

    func testBookLookupInvalidIdReturnsNil() {
        XCTAssertNil(db.book(id: 0))
        XCTAssertNil(db.book(id: 67))
    }

    func testGenesisHas50Chapters() {
        XCTAssertEqual(db.book(id: 1)?.chapterCount, 50)
    }

    // MARK: - Chapter counts

    func testPsalmsHas150Chapters() {
        XCTAssertEqual(db.chapterCount(bookId: 19), 150)
    }

    // MARK: - Verses

    func testGenesisChapter1Has31Verses() {
        XCTAssertEqual(db.verses(bookId: 1, chapter: 1).count, 31)
    }

    func testVerseOrderIsAscending() {
        let numbers = db.verses(bookId: 1, chapter: 1).map { $0.verse }
        XCTAssertEqual(numbers, Array(1...numbers.count))
    }

    func testJohn3v16Text() {
        let v = db.verse(bookId: 43, chapter: 3, verse: 16)
        XCTAssertNotNil(v)
        XCTAssertTrue(v?.text.contains("God so loved") == true)
    }

    func testGenesis1v1Text() {
        let v = db.verse(bookId: 1, chapter: 1, verse: 1)
        XCTAssertTrue(v?.text.lowercased().contains("in the beginning") == true)
    }

    func testInvalidVerseLookupReturnsNil() {
        XCTAssertNil(db.verse(bookId: 1, chapter: 1, verse: 9999))
        XCTAssertNil(db.verse(bookId: 99, chapter: 1, verse: 1))
    }

    func testVerseCountMatchesVersesArray() {
        let count  = db.verseCount(bookId: 43, chapter: 3)
        let verses = db.verses(bookId: 43, chapter: 3)
        XCTAssertEqual(count, verses.count)
        XCTAssertGreaterThan(count, 0)
    }

    func testVerseIdsAreUnique() {
        let ids = db.verses(bookId: 1, chapter: 1).map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    // MARK: - Full-text search

    func testSearchReturnsResults() {
        XCTAssertFalse(db.search("everlasting life").isEmpty)
    }

    func testSearchRespectsLimit() {
        XCTAssertLessThanOrEqual(db.search("Lord", limit: 5).count, 5)
    }

    func testSearchNonsenseReturnsEmpty() {
        XCTAssertTrue(db.search("xyzzy_nonsense_12345").isEmpty)
    }

    func testSearchResultsContainMatchingText() {
        for verse in db.search("love one another", limit: 10) {
            XCTAssertTrue(verse.text.lowercased().contains("love"))
        }
    }

    // MARK: - Words (Strong's)

    func testWordsForJohn3v16NotEmpty() {
        guard let v = db.verse(bookId: 43, chapter: 3, verse: 16) else {
            return XCTFail("John 3:16 not found")
        }
        XCTAssertFalse(db.words(forVerseId: v.id).isEmpty)
    }

    func testWordsAreOrderedByPosition() {
        guard let v = db.verse(bookId: 43, chapter: 3, verse: 16) else {
            return XCTFail("John 3:16 not found")
        }
        let positions = db.words(forVerseId: v.id).map { $0.position }
        XCTAssertEqual(positions, positions.sorted())
    }

    func testMajorityOfWordsHaveStrongsId() {
        guard let v = db.verse(bookId: 43, chapter: 3, verse: 16) else {
            return XCTFail("John 3:16 not found")
        }
        let words = db.words(forVerseId: v.id)
        let ratio = Double(words.filter { $0.strongsId != nil }.count) / Double(words.count)
        XCTAssertGreaterThan(ratio, 0.8)
    }

    // MARK: - Strong's concordance

    func testGreekStrongsLookup() {
        let e = db.strongs(id: "G3056")
        XCTAssertNotNil(e)
        XCTAssertEqual(e?.language, "greek")
        XCTAssertNotNil(e?.definition)
    }

    func testHebrewStrongsLookup() {
        let e = db.strongs(id: "H1697")
        XCTAssertNotNil(e)
        XCTAssertEqual(e?.language, "hebrew")
    }

    func testInvalidStrongsIdReturnsNil() {
        XCTAssertNil(db.strongs(id: "Z9999"))
        XCTAssertNil(db.strongs(id: ""))
    }

    func testStrongsGreekIdHasGPrefix() {
        XCTAssertTrue(db.strongs(id: "G3056")?.strongsId.hasPrefix("G") == true)
    }

    func testStrongsHebrewIdHasHPrefix() {
        XCTAssertTrue(db.strongs(id: "H7225")?.strongsId.hasPrefix("H") == true)
    }
}
