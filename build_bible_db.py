"""
Bible App - Data Pipeline
Step 1: KJV text → SQLite

Downloads KJV JSON from aruljohn/Bible-kjv and builds a structured
SQLite database ready for iOS/Xcode bundling.

Run: python3 build_bible_db.py
Output: bible.sqlite
"""

import json
import sqlite3
import urllib.request
import os

# ── Config ────────────────────────────────────────────────────────────────────

BASE_URL = "https://raw.githubusercontent.com/aruljohn/Bible-kjv/master"
OUTPUT_DB = "bible.sqlite"

# All 66 books in canonical order
BOOKS = [
    # Old Testament
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
    "Joshua", "Judges", "Ruth", "1Samuel", "2Samuel",
    "1Kings", "2Kings", "1Chronicles", "2Chronicles", "Ezra",
    "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
    "Ecclesiastes", "SongofSolomon", "Isaiah", "Jeremiah", "Lamentations",
    "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
    "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
    "Zephaniah", "Haggai", "Zechariah", "Malachi",
    # New Testament
    "Matthew", "Mark", "Luke", "John", "Acts",
    "Romans", "1Corinthians", "2Corinthians", "Galatians", "Ephesians",
    "Philippians", "Colossians", "1Thessalonians", "2Thessalonians", "1Timothy",
    "2Timothy", "Titus", "Philemon", "Hebrews", "James",
    "1Peter", "2Peter", "1John", "2John", "3John",
    "Jude", "Revelation"
]

# Display names (with spaces/punctuation) matching canonical order
BOOK_DISPLAY_NAMES = [
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

TESTAMENT = ["OT"] * 39 + ["NT"] * 27

# ── Database setup ─────────────────────────────────────────────────────────────

def create_schema(conn):
    """Create all tables. Designed to accommodate future datasets."""
    conn.executescript("""
        PRAGMA journal_mode=WAL;
        PRAGMA foreign_keys=ON;

        -- Books table
        CREATE TABLE IF NOT EXISTS books (
            book_id     INTEGER PRIMARY KEY,  -- 1-66, canonical order
            name        TEXT NOT NULL,        -- "Genesis"
            abbreviation TEXT,               -- "Gen" (added later)
            testament   TEXT NOT NULL,        -- "OT" or "NT"
            chapter_count INTEGER
        );

        -- Verses table (core of the app)
        CREATE TABLE IF NOT EXISTS verses (
            verse_id    INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id     INTEGER NOT NULL REFERENCES books(book_id),
            chapter     INTEGER NOT NULL,
            verse       INTEGER NOT NULL,
            text        TEXT NOT NULL,
            UNIQUE(book_id, chapter, verse)
        );

        -- Strong's numbers table (populated in Step 2)
        CREATE TABLE IF NOT EXISTS strongs (
            strongs_id  TEXT PRIMARY KEY,   -- e.g. "G3056" or "H1697"
            language    TEXT NOT NULL,       -- "greek" or "hebrew"
            lemma       TEXT,               -- original language word
            transliteration TEXT,
            pronunciation TEXT,
            definition  TEXT,
            part_of_speech TEXT,
            origin      TEXT
        );

        -- Word-level Strong's links (populated in Step 3)
        CREATE TABLE IF NOT EXISTS verse_words (
            word_id     INTEGER PRIMARY KEY AUTOINCREMENT,
            verse_id    INTEGER NOT NULL REFERENCES verses(verse_id),
            position    INTEGER NOT NULL,   -- word order in verse
            word        TEXT NOT NULL,       -- KJV English word
            strongs_id  TEXT REFERENCES strongs(strongs_id),
            grammar     TEXT                -- morphology code e.g. "V-AAI-3S"
        );

        -- User highlights (personal layer)
        CREATE TABLE IF NOT EXISTS highlights (
            highlight_id INTEGER PRIMARY KEY AUTOINCREMENT,
            verse_id     INTEGER NOT NULL REFERENCES verses(verse_id),
            color        TEXT NOT NULL DEFAULT 'yellow',
            created_at   TEXT NOT NULL DEFAULT (datetime('now'))
        );

        -- User notes (personal layer)
        CREATE TABLE IF NOT EXISTS notes (
            note_id     INTEGER PRIMARY KEY AUTOINCREMENT,
            verse_id    INTEGER NOT NULL REFERENCES verses(verse_id),
            body        TEXT NOT NULL,
            created_at  TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
        );

        -- Bookmarks (personal layer)
        CREATE TABLE IF NOT EXISTS bookmarks (
            bookmark_id INTEGER PRIMARY KEY AUTOINCREMENT,
            verse_id    INTEGER NOT NULL REFERENCES verses(verse_id),
            label       TEXT,
            created_at  TEXT NOT NULL DEFAULT (datetime('now'))
        );

        -- Search index (full-text search)
        CREATE VIRTUAL TABLE IF NOT EXISTS verses_fts
            USING fts5(text, content=verses, content_rowid=verse_id);
    """)
    conn.commit()
    print("✓ Schema created")


# ── Data fetching ──────────────────────────────────────────────────────────────

def fetch_book(filename):
    """Download a single book JSON from GitHub."""
    url = f"{BASE_URL}/{filename}.json"
    try:
        with urllib.request.urlopen(url) as r:
            return json.loads(r.read().decode())
    except Exception as e:
        print(f"  ✗ Failed to fetch {filename}: {e}")
        return None


def insert_book(conn, book_id, name, testament, data):
    """Insert a book and all its chapters/verses."""
    chapters = data.get("chapters", [])
    chapter_count = len(chapters)

    conn.execute(
        "INSERT OR IGNORE INTO books (book_id, name, testament, chapter_count) VALUES (?, ?, ?, ?)",
        (book_id, name, testament, chapter_count)
    )

    def extract_verse_text(verse_entry):
        if isinstance(verse_entry, str):
            return verse_entry
        if isinstance(verse_entry, dict):
            for key in ("text", "verse", "content"):
                value = verse_entry.get(key)
                if isinstance(value, str):
                    return value
            return json.dumps(verse_entry, ensure_ascii=False)
        return str(verse_entry)

    rows = []
    for ch_index, chapter in enumerate(chapters, start=1):
        for v_index, verse_text in enumerate(chapter.get("verses", []), start=1):
            normalized_text = extract_verse_text(verse_text).strip()
            rows.append((book_id, ch_index, v_index, normalized_text))

    conn.executemany(
        "INSERT OR IGNORE INTO verses (book_id, chapter, verse, text) VALUES (?, ?, ?, ?)",
        rows
    )
    return len(rows)


def build_fts_index(conn):
    """Populate the full-text search index."""
    conn.execute("INSERT INTO verses_fts(verses_fts) VALUES('rebuild')")
    conn.commit()
    print("✓ Full-text search index built")


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    # Remove existing DB so we start clean
    if os.path.exists(OUTPUT_DB):
        os.remove(OUTPUT_DB)
        print(f"Removed existing {OUTPUT_DB}")

    conn = sqlite3.connect(OUTPUT_DB)
    create_schema(conn)

    total_verses = 0
    print(f"\nDownloading {len(BOOKS)} books...\n")

    for i, (filename, display_name, testament) in enumerate(
        zip(BOOKS, BOOK_DISPLAY_NAMES, TESTAMENT), start=1
    ):
        print(f"  [{i:02d}/66] {display_name}...", end=" ", flush=True)
        data = fetch_book(filename)
        if data:
            count = insert_book(conn, i, display_name, testament, data)
            total_verses += count
            print(f"{count} verses")
        else:
            print("SKIPPED")

    conn.commit()
    build_fts_index(conn)

    # Summary
    print("\n── Summary ──────────────────────────────")
    cur = conn.execute("SELECT COUNT(*) FROM books")
    print(f"  Books:    {cur.fetchone()[0]}")
    cur = conn.execute("SELECT COUNT(*) FROM verses")
    print(f"  Verses:   {cur.fetchone()[0]:,}")
    cur = conn.execute("SELECT COUNT(*) FROM verses WHERE book_id <= 39")
    print(f"  OT verses: {cur.fetchone()[0]:,}")
    cur = conn.execute("SELECT COUNT(*) FROM verses WHERE book_id > 39")
    print(f"  NT verses: {cur.fetchone()[0]:,}")

    db_size = os.path.getsize(OUTPUT_DB) / 1024 / 1024
    print(f"  DB size:  {db_size:.2f} MB")
    print(f"\n✓ Saved to {OUTPUT_DB}")
    print("\nNext steps:")
    print("  Step 2: python3 import_strongs.py   (Strong's concordance)")
    print("  Step 3: python3 import_greek_nt.py  (Textus Receptus + parsing)")
    print("  Step 4: python3 import_hebrew_ot.py (Hebrew OT + morphology)")

    conn.close()


if __name__ == "__main__":
    main()
