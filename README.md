# bible_lite
My own personal Bible app — a local SQLite-backed iOS Bible reader with Strong's concordance, Greek NT, and Hebrew OT word-level data.

## Project overview
The pipeline builds a single `bible.sqlite` database that is bundled directly into the Xcode app. No network requests are needed at runtime.

## Data pipeline

Run the four scripts in order from the `Desktop` directory:

### Step 1 — KJV text
```
python3 build_bible_db.py
```
- Downloads all 66 KJV books from [aruljohn/Bible-kjv](https://github.com/aruljohn/Bible-kjv)
- Creates `bible.sqlite` with the `books`, `verses`, and `verses_fts` (FTS5) tables
- Output: 66 books, 31,102 verses

### Step 2 — Strong's concordance
```
python3 import_strongs.py
```
- Downloads Strong's Greek and Hebrew dictionaries
- Populates the `strongs` table
- Output: 5,523 Greek entries, 8,674 Hebrew entries

### Step 3 — Greek New Testament
```
python3 import_greek_nt.py
```
- Downloads the Textus Receptus parsed Greek NT from [byztxt/greektext-textus-receptus](https://github.com/byztxt/greektext-textus-receptus) (`.UTR` format)
- Populates `verse_words` for NT books with Greek words, Strong's IDs, and grammar codes
- Output: 141,881 words across 27 NT books

### Step 4 — Hebrew Old Testament
```
python3 import_hebrew_ot.py
```
- Downloads morphologically tagged Hebrew OT from the morphhb project
- Populates `verse_words` for OT books with Hebrew words, Strong's IDs, and grammar codes
- Output: 304,400 words across 39 OT books

### Final database stats
| Table | Count |
|---|---|
| Books | 66 |
| Verses | 31,102 |
| Verse words | 446,281 |
| Strong's entries | 14,197 |
| DB size | ~25.7 MB |

## Running the tests

### Python (verse normalization)
```
python3 -m unittest test_build_bible_db.py -v
```
Covers `insert_book` verse normalization for string, dict, and fallback types.

### Swift / Xcode
Open `bible_lite/bible_lite.xcodeproj` in Xcode and press **⌘U**.
Requires the `bible_liteTests` unit test target with `bible.sqlite` added to its Copy Bundle Resources build phase.

## Xcode setup

1. Drag `bible.sqlite` into the Xcode project navigator
   - Check **Copy items if needed**
   - Check your app target under **Add to targets**
2. Add `DatabaseManager.swift`, `BookListView.swift` to the app target
3. Add `DatabaseManagerTests.swift` to the `bible_liteTests` target
4. Build and run with **⌘R**, test with **⌘U**

## Swift data layer

`DatabaseManager.swift` is a singleton that wraps all SQLite queries:

| Method | Description |
|---|---|
| `allBooks()` | All 66 books |
| `book(id:)` | Single book by canonical ID |
| `verses(bookId:chapter:)` | All verses in a chapter |
| `verse(bookId:chapter:verse:)` | Single verse lookup |
| `search(_:limit:)` | FTS5 full-text search |
| `words(forVerseId:)` | Word-level Strong's data |
| `strongs(id:)` | Strong's concordance entry |
| `chapterCount(bookId:)` | Number of chapters |
| `verseCount(bookId:chapter:)` | Number of verses in a chapter |

## Bug fixes
- Fixed `AttributeError` in `build_bible_db.py` — verse entries from the upstream JSON can be dicts instead of strings. Added `extract_verse_text()` normalizer with dict key fallback (`text` → `verse` → `content`) and `str()` coercion for all other types.
- Fixed `import_greek_nt.py` — source files use `.UTR` extension with abbreviated book names (`MT`, `MR`, `LU`, `AC`, `RO`, etc.) not `.txt`. Updated filename mapping and rewrote parser to handle the `chapter:verse word strongs {grammar}` format with multi-line verse continuations.
