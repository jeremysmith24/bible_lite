import XCTest
@testable import bible_lite

final class BibleReferenceParserTests: XCTestCase {

    // MARK: - Abbreviation coverage

    func testCommonNTAbbreviations() {
        let cases: [(String, String)] = [
            ("mat",  "Matthew"),  ("matt", "Matthew"), ("mt",   "Matthew"),
            ("mk",   "Mark"),     ("mar",  "Mark"),     ("mark", "Mark"),
            ("lk",   "Luke"),     ("luke", "Luke"),
            ("jn",   "John"),     ("joh",  "John"),
            ("ac",   "Acts"),     ("acts", "Acts"),
            ("ro",   "Romans"),   ("rom",  "Romans"),
            ("gal",  "Galatians"),
            ("eph",  "Ephesians"),
            ("php",  "Philippians"),
            ("col",  "Colossians"),
            ("heb",  "Hebrews"),
            ("jas",  "James"),    ("jam",  "James"),
            ("rev",  "Revelation"),
        ]
        for (abbr, expected) in cases {
            XCTAssertEqual(
                BibleReferenceParser.abbreviations[abbr], expected,
                "abbreviations[\"\(abbr)\"] should be \"\(expected)\""
            )
        }
    }

    func testCommonOTAbbreviations() {
        let cases: [(String, String)] = [
            ("gen",  "Genesis"),  ("ge",   "Genesis"),
            ("ex",   "Exodus"),   ("exo",  "Exodus"),
            ("lev",  "Leviticus"),
            ("num",  "Numbers"),  ("nu",   "Numbers"),
            ("deut", "Deuteronomy"),
            ("ps",   "Psalms"),   ("psa",  "Psalms"), ("psalm", "Psalms"),
            ("prov", "Proverbs"), ("pr",   "Proverbs"),
            ("isa",  "Isaiah"),
            ("jer",  "Jeremiah"),
            ("dan",  "Daniel"),
            ("mal",  "Malachi"),
        ]
        for (abbr, expected) in cases {
            XCTAssertEqual(
                BibleReferenceParser.abbreviations[abbr], expected,
                "abbreviations[\"\(abbr)\"] should be \"\(expected)\""
            )
        }
    }

    func testNumberedBookAbbreviations() {
        let cases: [(String, String)] = [
            ("1sam",  "1 Samuel"), ("2sam",  "2 Samuel"),
            ("1kgs",  "1 Kings"),  ("2kgs",  "2 Kings"),
            ("1cor",  "1 Corinthians"), ("2cor", "2 Corinthians"),
            ("1th",   "1 Thessalonians"), ("2th", "2 Thessalonians"),
            ("1tim",  "1 Timothy"), ("2tim", "2 Timothy"),
            ("1pet",  "1 Peter"),  ("2pet",  "2 Peter"),
            ("1jn",   "1 John"),   ("2jn",   "2 John"), ("3jn", "3 John"),
        ]
        for (abbr, expected) in cases {
            XCTAssertEqual(
                BibleReferenceParser.abbreviations[abbr], expected,
                "abbreviations[\"\(abbr)\"] should be \"\(expected)\""
            )
        }
    }

    // MARK: - Full reference parsing

    func testParseBookOnly() {
        let ref = BibleReferenceParser.parse("Matthew")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.bookId, 40)
        XCTAssertEqual(ref?.bookName, "Matthew")
        XCTAssertNil(ref?.chapter)
        XCTAssertNil(ref?.verse)
    }

    func testParseAbbreviationBookOnly() {
        let ref = BibleReferenceParser.parse("Mat")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.bookName, "Matthew")
        XCTAssertNil(ref?.chapter)
    }

    func testParseBookAndChapter() {
        let ref = BibleReferenceParser.parse("John 3")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.bookId, 43)
        XCTAssertEqual(ref?.chapter, 3)
        XCTAssertNil(ref?.verse)
    }

    func testParseFullVerseReference() {
        let ref = BibleReferenceParser.parse("Jn 3:16")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.bookName, "John")
        XCTAssertEqual(ref?.chapter, 3)
        XCTAssertEqual(ref?.verse, 16)
    }

    func testParseGenesis1v1() {
        let ref = BibleReferenceParser.parse("Gen 1:1")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.bookId, 1)
        XCTAssertEqual(ref?.chapter, 1)
        XCTAssertEqual(ref?.verse, 1)
    }

    func testParsePsalms23() {
        let ref = BibleReferenceParser.parse("Ps 23")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.bookName, "Psalms")
        XCTAssertEqual(ref?.chapter, 23)
        XCTAssertNil(ref?.verse)
    }

    func testParseNumberedBookWithChapterVerse() {
        let ref = BibleReferenceParser.parse("1 Cor 13:4")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.bookName, "1 Corinthians")
        XCTAssertEqual(ref?.chapter, 13)
        XCTAssertEqual(ref?.verse, 4)
    }

    func testParseAbbreviatedNumberedBook() {
        let ref = BibleReferenceParser.parse("1cor 13:4")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.bookName, "1 Corinthians")
        XCTAssertEqual(ref?.chapter, 13)
        XCTAssertEqual(ref?.verse, 4)
    }

    func testParseRevelation22v21() {
        let ref = BibleReferenceParser.parse("Rev 22:21")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.bookId, 66)
        XCTAssertEqual(ref?.chapter, 22)
        XCTAssertEqual(ref?.verse, 21)
    }

    func testParseCaseInsensitive() {
        XCTAssertNotNil(BibleReferenceParser.parse("gen 1:1"))
        XCTAssertNotNil(BibleReferenceParser.parse("GEN 1:1"))
        XCTAssertNotNil(BibleReferenceParser.parse("Gen 1:1"))
        XCTAssertNotNil(BibleReferenceParser.parse("gEn 1:1"))
    }

    func testParseLeadingAndTrailingWhitespace() {
        let ref = BibleReferenceParser.parse("  Matt 5:3  ")
        XCTAssertNotNil(ref)
        XCTAssertEqual(ref?.bookName, "Matthew")
        XCTAssertEqual(ref?.chapter, 5)
        XCTAssertEqual(ref?.verse, 3)
    }

    // MARK: - Display string

    func testDisplayStringBookOnly() {
        let ref = BibleReferenceParser.parse("Genesis")
        XCTAssertEqual(ref?.displayString, "Genesis")
    }

    func testDisplayStringChapter() {
        let ref = BibleReferenceParser.parse("John 3")
        XCTAssertEqual(ref?.displayString, "John 3")
    }

    func testDisplayStringFullReference() {
        let ref = BibleReferenceParser.parse("Jn 3:16")
        XCTAssertEqual(ref?.displayString, "John 3:16")
    }

    // MARK: - Invalid inputs

    func testParseEmptyStringReturnsNil() {
        XCTAssertNil(BibleReferenceParser.parse(""))
    }

    func testParseGibberishReturnsNil() {
        XCTAssertNil(BibleReferenceParser.parse("xyzzy"))
        XCTAssertNil(BibleReferenceParser.parse("foo bar 1:1"))
        XCTAssertNil(BibleReferenceParser.parse("12345"))
    }

    // MARK: - Suggestions

    func testSuggestionsForMatMatchesMatthew() {
        let suggestions = BibleReferenceParser.suggestions(for: "mat")
        XCTAssertTrue(suggestions.contains("Matthew"), "\"mat\" should suggest Matthew")
    }

    func testSuggestionsForJnMatchesJohnVariants() {
        let suggestions = BibleReferenceParser.suggestions(for: "jn")
        XCTAssertTrue(suggestions.contains("John"))
        XCTAssertTrue(suggestions.contains("1 John"))
        XCTAssertTrue(suggestions.contains("2 John"))
        XCTAssertTrue(suggestions.contains("3 John"))
    }

    func testSuggestionsForPsMatchesPsalms() {
        let suggestions = BibleReferenceParser.suggestions(for: "ps")
        XCTAssertTrue(suggestions.contains("Psalms"))
    }

    func testSuggestionsForGeMatchesGenesis() {
        let suggestions = BibleReferenceParser.suggestions(for: "ge")
        XCTAssertTrue(suggestions.contains("Genesis"))
    }

    func testSuggestionsAreOrderedCanonically() {
        let suggestions = BibleReferenceParser.suggestions(for: "j")
        // Joshua (6), Judges (7), Job (18), Joel (29), Jonah (32) all before
        // John (43), James (59), Jude (65)
        if let josIdx = suggestions.firstIndex(of: "Joshua"),
           let johnIdx = suggestions.firstIndex(of: "John") {
            XCTAssertLessThan(josIdx, johnIdx, "Joshua should appear before John")
        }
    }

    func testSuggestionsForEmptyStringReturnsEmpty() {
        XCTAssertTrue(BibleReferenceParser.suggestions(for: "").isEmpty)
    }

    func testSuggestionsForGibberishReturnsEmpty() {
        XCTAssertTrue(BibleReferenceParser.suggestions(for: "xyzzy").isEmpty)
    }

    func testSuggestionsDeduplicateBooks() {
        // "gen" and "ge" both map to Genesis — should only appear once
        let suggestions = BibleReferenceParser.suggestions(for: "gen")
        let genesisCount = suggestions.filter { $0 == "Genesis" }.count
        XCTAssertEqual(genesisCount, 1, "Genesis should appear exactly once in suggestions")
    }
}
