import Foundation

// MARK: - Parsed Reference

struct BibleReference {
    let bookId: Int
    let bookName: String
    let chapter: Int?
    let verse: Int?

    var displayString: String {
        var s = bookName
        if let ch = chapter {
            s += " \(ch)"
            if let v = verse { s += ":\(v)" }
        }
        return s
    }
}

// MARK: - Parser

enum BibleReferenceParser {

    // All standard abbreviations → canonical book name
    static let abbreviations: [String: String] = [
        // Genesis
        "gen": "Genesis", "ge": "Genesis",
        // Exodus
        "ex": "Exodus", "exo": "Exodus",
        // Leviticus
        "lev": "Leviticus", "le": "Leviticus",
        // Numbers
        "num": "Numbers", "nu": "Numbers", "nb": "Numbers",
        // Deuteronomy
        "deut": "Deuteronomy", "deu": "Deuteronomy", "dt": "Deuteronomy",
        // Joshua
        "josh": "Joshua", "jos": "Joshua",
        // Judges
        "judg": "Judges", "jdg": "Judges", "jg": "Judges",
        // Ruth
        "ruth": "Ruth", "ru": "Ruth", "rth": "Ruth",
        // 1 Samuel
        "1sam": "1 Samuel", "1sa": "1 Samuel", "1 sam": "1 Samuel",
        // 2 Samuel
        "2sam": "2 Samuel", "2sa": "2 Samuel", "2 sam": "2 Samuel",
        // 1 Kings
        "1kgs": "1 Kings", "1ki": "1 Kings", "1 kgs": "1 Kings",
        // 2 Kings
        "2kgs": "2 Kings", "2ki": "2 Kings", "2 kgs": "2 Kings",
        // 1 Chronicles
        "1chr": "1 Chronicles", "1ch": "1 Chronicles", "1 chr": "1 Chronicles",
        // 2 Chronicles
        "2chr": "2 Chronicles", "2ch": "2 Chronicles", "2 chr": "2 Chronicles",
        // Ezra
        "ezr": "Ezra",
        // Nehemiah
        "neh": "Nehemiah",
        // Esther
        "est": "Esther", "esth": "Esther",
        // Job
        "job": "Job",
        // Psalms
        "ps": "Psalms", "psa": "Psalms", "pss": "Psalms", "psalm": "Psalms",
        // Proverbs
        "prov": "Proverbs", "pro": "Proverbs", "pr": "Proverbs",
        // Ecclesiastes
        "eccl": "Ecclesiastes", "ecc": "Ecclesiastes", "ec": "Ecclesiastes",
        // Song of Solomon
        "song": "Song of Solomon", "sos": "Song of Solomon",
        "ss": "Song of Solomon", "sol": "Song of Solomon",
        // Isaiah
        "isa": "Isaiah",
        // Jeremiah
        "jer": "Jeremiah",
        // Lamentations
        "lam": "Lamentations",
        // Ezekiel
        "ezek": "Ezekiel", "eze": "Ezekiel",
        // Daniel
        "dan": "Daniel",
        // Hosea
        "hos": "Hosea",
        // Joel
        "joel": "Joel",
        // Amos
        "amos": "Amos",
        // Obadiah
        "obad": "Obadiah", "ob": "Obadiah",
        // Jonah
        "jon": "Jonah",
        // Micah
        "mic": "Micah",
        // Nahum
        "nah": "Nahum",
        // Habakkuk
        "hab": "Habakkuk",
        // Zephaniah
        "zeph": "Zephaniah", "zep": "Zephaniah",
        // Haggai
        "hag": "Haggai",
        // Zechariah
        "zech": "Zechariah", "zec": "Zechariah",
        // Malachi
        "mal": "Malachi",
        // Matthew
        "mat": "Matthew", "matt": "Matthew", "mt": "Matthew",
        // Mark
        "mark": "Mark", "mk": "Mark", "mar": "Mark",
        // Luke
        "luke": "Luke", "lk": "Luke",
        // John
        "jn": "John", "joh": "John",
        // Acts
        "acts": "Acts", "ac": "Acts",
        // Romans
        "rom": "Romans", "ro": "Romans",
        // 1 Corinthians
        "1cor": "1 Corinthians", "1co": "1 Corinthians", "1 cor": "1 Corinthians",
        // 2 Corinthians
        "2cor": "2 Corinthians", "2co": "2 Corinthians", "2 cor": "2 Corinthians",
        // Galatians
        "gal": "Galatians",
        // Ephesians
        "eph": "Ephesians",
        // Philippians
        "phil": "Philippians", "php": "Philippians",
        // Colossians
        "col": "Colossians",
        // 1 Thessalonians
        "1thess": "1 Thessalonians", "1th": "1 Thessalonians", "1 thess": "1 Thessalonians",
        // 2 Thessalonians
        "2thess": "2 Thessalonians", "2th": "2 Thessalonians", "2 thess": "2 Thessalonians",
        // 1 Timothy
        "1tim": "1 Timothy", "1ti": "1 Timothy", "1 tim": "1 Timothy",
        // 2 Timothy
        "2tim": "2 Timothy", "2ti": "2 Timothy", "2 tim": "2 Timothy",
        // Titus
        "tit": "Titus",
        // Philemon
        "philem": "Philemon", "phm": "Philemon",
        // Hebrews
        "heb": "Hebrews",
        // James
        "jas": "James", "jam": "James",
        // 1 Peter
        "1pet": "1 Peter", "1pe": "1 Peter", "1 pet": "1 Peter",
        // 2 Peter
        "2pet": "2 Peter", "2pe": "2 Peter", "2 pet": "2 Peter",
        // 1 John
        "1jn": "1 John", "1jo": "1 John", "1 jn": "1 John",
        // 2 John
        "2jn": "2 John", "2jo": "2 John", "2 jn": "2 John",
        // 3 John
        "3jn": "3 John", "3jo": "3 John", "3 jn": "3 John",
        // Jude
        "jude": "Jude",
        // Revelation
        "rev": "Revelation", "re": "Revelation",
    ]

    // bookName → bookId (1–66)
    private static let bookIds: [String: Int] = {
        let names = [
            "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
            "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
            "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra",
            "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
            "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations",
            "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
            "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
            "Zephaniah", "Haggai", "Zechariah", "Malachi",
            "Matthew", "Mark", "Luke", "John", "Acts",
            "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
            "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy",
            "2 Timothy", "Titus", "Philemon", "Hebrews", "James",
            "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
            "Jude", "Revelation"
        ]
        return Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0 + 1) })
    }()

    /// Parse a query like "Mat 3:16", "Gen 1", "John", "jn 3"
    /// Returns a BibleReference when a book (and optionally chapter/verse) is detected.
    static func parse(_ query: String) -> BibleReference? {
        let input = query.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return nil }

        // Regex: optional leading number + book word(s) + optional chapter + optional :verse
        // e.g. "1 John 3:16", "Matt 5", "Gen", "ps 23"
        let pattern = #"^(\d\s*)?([a-zA-Z]+(?:\s+[a-zA-Z]+)?)(?:\s+(\d+))?(?::(\d+))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: input,
                                           range: NSRange(input.startIndex..., in: input))
        else { return nil }

        func group(_ i: Int) -> String? {
            guard match.range(at: i).location != NSNotFound,
                  let range = Range(match.range(at: i), in: input)
            else { return nil }
            return String(input[range]).trimmingCharacters(in: .whitespaces)
        }

        let prefix = group(1) ?? ""             // "1", "2", "3" or ""
        let bookWord = group(2) ?? ""            // "Mat", "John", "Sam"
        let chapter = group(3).flatMap { Int($0) }
        let verse   = group(4).flatMap { Int($0) }

        let raw = (prefix + bookWord).lowercased()
            .replacingOccurrences(of: " ", with: "")

        // First try exact abbreviation lookup
        var bookName: String?
        if let name = abbreviations[raw] {
            bookName = name
        } else {
            // Then try prefix match against full book names
            let lower = (prefix + bookWord).lowercased()
            bookName = bookIds.keys.first { $0.lowercased().hasPrefix(lower) }
                    ?? bookIds.keys.first { $0.lowercased().contains(lower) }
        }

        guard let name = bookName, let id = bookIds[name] else { return nil }
        return BibleReference(bookId: id, bookName: name, chapter: chapter, verse: verse)
    }

    /// Returns book names whose names or abbreviations begin with the given prefix.
    /// Used to show suggestion chips while typing.
    static func suggestions(for prefix: String) -> [String] {
        let lower = prefix.lowercased().trimmingCharacters(in: .whitespaces)
        guard lower.count >= 1 else { return [] }

        var matched = Set<String>()

        // Books whose name starts with prefix
        for name in bookIds.keys where name.lowercased().hasPrefix(lower) {
            matched.insert(name)
        }
        // Books reachable via abbreviation
        for (abbr, name) in abbreviations where abbr.hasPrefix(lower) {
            matched.insert(name)
        }

        return matched.sorted { (bookIds[$0] ?? 0) < (bookIds[$1] ?? 0) }
    }
}
