"""
Bible App - Data Pipeline
Step 3: Textus Receptus Greek NT → SQLite

Downloads the TR Greek NT from byztxt/greektext-textus-receptus.
Each file is one NT book in .UTR format:
    chapter:verse greek_word strongs [optional_morph_number] {grammar}

Run AFTER import_strongs.py:
    python3 import_greek_nt.py

Requires: bible.sqlite in the same folder
"""

import os
import re
import sqlite3
import urllib.request

# ── Config ─────────────────────────────────────────────────────────────────────

DB_PATH = "bible.sqlite"
BASE_URL = "https://raw.githubusercontent.com/byztxt/greektext-textus-receptus/master/parsed"

# NT books: (filename_prefix, book_id 40-66, display_name)
NT_BOOKS = [
    ("MT", 40, "Matthew"), ("MR", 41, "Mark"),
    ("LU", 42, "Luke"), ("JOH", 43, "John"),
    ("AC", 44, "Acts"), ("RO", 45, "Romans"),
    ("1CO", 46, "1 Corinthians"), ("2CO", 47, "2 Corinthians"),
    ("GA", 48, "Galatians"), ("EPH", 49, "Ephesians"),
    ("PHP", 50, "Philippians"), ("COL", 51, "Colossians"),
    ("1TH", 52, "1 Thessalonians"), ("2TH", 53, "2 Thessalonians"),
    ("1TI", 54, "1 Timothy"), ("2TI", 55, "2 Timothy"),
    ("TIT", 56, "Titus"), ("PHM", 57, "Philemon"),
    ("HEB", 58, "Hebrews"), ("JAS", 59, "James"),
    ("1PE", 60, "1 Peter"), ("2PE", 61, "2 Peter"),
    ("1JO", 62, "1 John"), ("2JO", 63, "2 John"),
    ("3JO", 64, "3 John"), ("JUDE", 65, "Jude"),
    ("RE", 66, "Revelation"),
]

# Optional legacy aliases in case upstream naming changes
FILENAME_ALIASES = {
    "MT": ["MAT"],
    "MR": ["MAR"],
    "LU": ["LUK"],
    "AC": ["ACT"],
    "RO": ["ROM"],
    "GA": ["GAL"],
    "JAS": ["JAM"],
    "JUDE": ["JUD"],
    "RE": ["REV"],
}


# ── Helpers ────────────────────────────────────────────────────────────────────

def fetch_book_text(abbrev):
    """Download one parsed file. Returns lines list or None."""
    candidates = [abbrev] + FILENAME_ALIASES.get(abbrev, [])
    exts = [".UTR", ".txt"]
    last_error = None

    for candidate in candidates:
        for ext in exts:
            url = f"{BASE_URL}/{candidate}{ext}"
            try:
                with urllib.request.urlopen(url) as r:
                    return r.read().decode("utf-8").splitlines()
            except Exception as e:
                last_error = e

    print(f"\n    ✗ Could not fetch {abbrev}: {last_error}")
    return None


def parse_reference(ref_str):
    """Parse chapter:verse like '3:16' -> (3, 16)."""
    m = re.match(r"^(\d+):(\d+)$", ref_str.strip())
    if not m:
        return None
    return int(m.group(1)), int(m.group(2))


def clean_strongs(raw):
    """
    Normalise a Strong's number from TR files.
    Examples: '3056' -> 'G3056', 'G3056' -> 'G3056', '3056a' -> 'G3056'
    """
    if not raw:
        return None
    raw = raw.strip()
    if raw.startswith("G") or raw.startswith("H"):
        return re.sub(r"[^A-Z0-9]", "", raw)
    digits = re.sub(r"[^0-9]", "", raw)
    return f"G{digits}" if digits else None


def get_verse_id(conn, book_id, chapter, verse):
    """Look up verse_id from verses table."""
    cur = conn.execute(
        "SELECT verse_id FROM verses WHERE book_id=? AND chapter=? AND verse=?",
        (book_id, chapter, verse),
    )
    row = cur.fetchone()
    return row[0] if row else None


def build_verse_chunks(lines):
    """
    Collapse multi-line .UTR input into [(ref, verse_body)] chunks.
    New verse lines start with chapter:verse; following indented lines continue it.
    """
    verse_chunks = []
    current_ref = None
    current_parts = []

    for raw in lines:
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue

        m = re.match(r"^(\d+:\d+)\s+(.+)$", line.strip())
        if m:
            if current_ref is not None:
                verse_chunks.append((current_ref, " ".join(current_parts)))
            current_ref = m.group(1)
            current_parts = [m.group(2).strip()]
        elif current_ref is not None:
            current_parts.append(line.strip())

    if current_ref is not None:
        verse_chunks.append((current_ref, " ".join(current_parts)))
    return verse_chunks


def import_book(conn, lines, book_id):
    """
    Parse a .UTR book and insert words into verse_words.
    Token stream pattern generally looks like:
      greek_word strongs [optional_morph_number] {grammar}
    """
    rows = []
    verse_chunks = build_verse_chunks(lines)

    for ref_str, verse_text in verse_chunks:
        ref = parse_reference(ref_str)
        if not ref:
            continue

        chapter, verse = ref
        verse_id = get_verse_id(conn, book_id, chapter, verse)
        if not verse_id:
            continue

        tokens = verse_text.split()
        pos = 0
        i = 0

        while i < len(tokens):
            tok = tokens[i]

            if tok.startswith("{") and tok.endswith("}"):
                i += 1
                continue

            greek_word = tok
            i += 1

            strongs_raw = None
            grammar = None

            if i < len(tokens) and re.match(r"^[GH]?\d+[A-Za-z]?$", tokens[i]):
                strongs_raw = tokens[i]
                i += 1

                if i < len(tokens) and re.match(r"^\d+$", tokens[i]):
                    i += 1

            if i < len(tokens) and tokens[i].startswith("{") and tokens[i].endswith("}"):
                grammar = tokens[i][1:-1]
                i += 1

            strongs_id = clean_strongs(strongs_raw)
            pos += 1
            rows.append((verse_id, pos, greek_word, strongs_id, grammar))

    if rows:
        conn.executemany(
            """
            INSERT OR IGNORE INTO verse_words
                (verse_id, position, word, strongs_id, grammar)
            VALUES (?, ?, ?, ?, ?)
            """,
            rows,
        )
        conn.commit()
    return len(rows)


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    if not os.path.exists(DB_PATH):
        print(f"✗ {DB_PATH} not found. Run build_bible_db.py first.")
        return

    conn = sqlite3.connect(DB_PATH)
    print("Importing Textus Receptus Greek NT...\n")

    total_words = 0
    for abbrev, book_id, name in NT_BOOKS:
        print(f"  {name}...", end=" ", flush=True)
        lines = fetch_book_text(abbrev)
        if lines:
            count = import_book(conn, lines, book_id)
            total_words += count
            print(f"{count:,} words")
        else:
            print("SKIPPED")

    print("\n── Summary ──────────────────────────────")
    cur = conn.execute("SELECT COUNT(*) FROM verse_words")
    print(f"  Total Greek words: {cur.fetchone()[0]:,}")

    cur = conn.execute("SELECT COUNT(*) FROM verse_words WHERE strongs_id IS NOT NULL")
    print(f"  Words with Strong's: {cur.fetchone()[0]:,}")

    cur = conn.execute("SELECT COUNT(*) FROM verse_words WHERE grammar IS NOT NULL")
    print(f"  Words with parsing: {cur.fetchone()[0]:,}")

    cur = conn.execute(
        """
        SELECT vw.position, vw.word, vw.strongs_id, vw.grammar
        FROM verse_words vw
        JOIN verses v ON vw.verse_id = v.verse_id
        WHERE v.book_id = 43 AND v.chapter = 3 AND v.verse = 16
        ORDER BY vw.position
        LIMIT 5
        """
    )
    rows = cur.fetchall()
    if rows:
        print("\n  Spot check John 3:16 (first 5 words):")
        for pos, word, sid, gram in rows:
            print(f"    {pos}. {word:<20} {str(sid):<8} {gram or ''}")

    conn.close()
    print(f"\n✓ Greek NT data saved to {DB_PATH}")
    print("\nNext: python3 import_hebrew_ot.py")


if __name__ == "__main__":
    main()