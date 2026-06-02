"""
Bible App - Data Pipeline
Step 4: Hebrew OT (morphhb) → SQLite

Downloads the Open Scriptures Hebrew Bible (OSHB) OSIS XML files
from openscriptures/morphhb — one file per OT book.
Each word is tagged with Strong's numbers and morphology codes.

Run AFTER import_greek_nt.py:
    python3 import_hebrew_ot.py

Requires: bible.sqlite in the same folder
"""

import sqlite3
import urllib.request
import os
import re
import xml.etree.ElementTree as ET

# ── Config ─────────────────────────────────────────────────────────────────────

DB_PATH  = "bible.sqlite"
BASE_URL = "https://raw.githubusercontent.com/openscriptures/morphhb/master/wlc"

# OT books: (filename, book_id 1-39, display_name)
OT_BOOKS = [
    ("Gen.xml",  1,  "Genesis"),      ("Exod.xml",  2,  "Exodus"),
    ("Lev.xml",  3,  "Leviticus"),    ("Num.xml",   4,  "Numbers"),
    ("Deut.xml", 5,  "Deuteronomy"),  ("Josh.xml",  6,  "Joshua"),
    ("Judg.xml", 7,  "Judges"),       ("Ruth.xml",  8,  "Ruth"),
    ("1Sam.xml", 9,  "1 Samuel"),     ("2Sam.xml",  10, "2 Samuel"),
    ("1Kgs.xml", 11, "1 Kings"),      ("2Kgs.xml",  12, "2 Kings"),
    ("1Chr.xml", 13, "1 Chronicles"), ("2Chr.xml",  14, "2 Chronicles"),
    ("Ezra.xml", 15, "Ezra"),         ("Neh.xml",   16, "Nehemiah"),
    ("Esth.xml", 17, "Esther"),       ("Job.xml",   18, "Job"),
    ("Ps.xml",   19, "Psalms"),       ("Prov.xml",  20, "Proverbs"),
    ("Eccl.xml", 21, "Ecclesiastes"), ("Song.xml",  22, "Song of Solomon"),
    ("Isa.xml",  23, "Isaiah"),       ("Jer.xml",   24, "Jeremiah"),
    ("Lam.xml",  25, "Lamentations"), ("Ezek.xml",  26, "Ezekiel"),
    ("Dan.xml",  27, "Daniel"),       ("Hos.xml",   28, "Hosea"),
    ("Joel.xml", 29, "Joel"),         ("Amos.xml",  30, "Amos"),
    ("Obad.xml", 31, "Obadiah"),      ("Jonah.xml", 32, "Jonah"),
    ("Mic.xml",  33, "Micah"),        ("Nah.xml",   34, "Nahum"),
    ("Hab.xml",  35, "Habakkuk"),     ("Zeph.xml",  36, "Zephaniah"),
    ("Hag.xml",  37, "Haggai"),       ("Zech.xml",  38, "Zechariah"),
    ("Mal.xml",  39, "Malachi"),
]

# OSIS XML namespace
NS = {"osis": "http://www.bibletechnologies.net/2003/OSIS/namespace"}

# ── Helpers ────────────────────────────────────────────────────────────────────

def fetch_xml(filename):
    """Download one OSIS XML book file."""
    url = f"{BASE_URL}/{filename}"
    try:
        with urllib.request.urlopen(url) as r:
            return r.read()
    except Exception as e:
        print(f"\n    ✗ Could not fetch {filename}: {e}")
        return None


def parse_osisID(osisID):
    """
    Parse an OSIS verse ID like 'Gen.1.1' → (chapter, verse).
    Returns None if unparseable.
    """
    parts = osisID.split(".")
    if len(parts) >= 3:
        try:
            return int(parts[1]), int(parts[2])
        except ValueError:
            pass
    return None


def clean_hebrew_strongs(lemma_attr):
    """
    The morphhb lemma attribute can look like:
        '1234'  → H1234
        'a/1234' → H1234  (prefix stripped)
        '1234a' → H1234   (variant letter stripped)
        'b/1234/c' → multiple — take the main number
    Returns 'H####' or None.
    """
    if not lemma_attr:
        return None
    # Take last slash-separated segment that looks like a number
    parts = lemma_attr.split("/")
    for part in reversed(parts):
        part = part.strip()
        digits = re.sub(r'[^0-9]', '', part)
        if digits:
            return f"H{digits}"
    return None


def get_verse_id(conn, book_id, chapter, verse):
    cur = conn.execute(
        "SELECT verse_id FROM verses WHERE book_id=? AND chapter=? AND verse=?",
        (book_id, chapter, verse)
    )
    row = cur.fetchone()
    return row[0] if row else None


def import_book_xml(conn, xml_bytes, book_id):
    """
    Parse OSIS XML and extract word-level data.
    Each <w> element has:
        lemma  = Strong's number(s)
        morph  = morphology code (e.g. 'He,Ncmsa')
        text content = Hebrew word
    """
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError as e:
        print(f"\n    ✗ XML parse error: {e}")
        return 0

    rows = []
    position_tracker = {}

    # Walk all verse elements
    for verse_el in root.iter("{http://www.bibletechnologies.net/2003/OSIS/namespace}verse"):
        osisID = verse_el.get("osisID", "")
        ref = parse_osisID(osisID)
        if not ref:
            continue
        chapter, verse_num = ref
        verse_id = get_verse_id(conn, book_id, chapter, verse_num)
        if not verse_id:
            continue

        # Walk <w> (word) elements within the verse
        for w_el in verse_el.iter("{http://www.bibletechnologies.net/2003/OSIS/namespace}w"):
            hebrew_word = (w_el.text or "").strip()
            if not hebrew_word:
                continue

            lemma_attr = w_el.get("lemma", "")
            morph_attr = w_el.get("morph", "")
            strongs_id = clean_hebrew_strongs(lemma_attr)

            pos = position_tracker.get(verse_id, 0) + 1
            position_tracker[verse_id] = pos

            rows.append((verse_id, pos, hebrew_word, strongs_id, morph_attr or None))

    if rows:
        conn.executemany("""
            INSERT OR IGNORE INTO verse_words
                (verse_id, position, word, strongs_id, grammar)
            VALUES (?, ?, ?, ?, ?)
        """, rows)
        conn.commit()
    return len(rows)


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    if not os.path.exists(DB_PATH):
        print(f"✗ {DB_PATH} not found. Run build_bible_db.py first.")
        return

    conn = sqlite3.connect(DB_PATH)
    print("Importing Hebrew OT (morphhb)...\n")

    total_words = 0
    for filename, book_id, name in OT_BOOKS:
        print(f"  {name}...", end=" ", flush=True)
        xml_bytes = fetch_xml(filename)
        if xml_bytes:
            count = import_book_xml(conn, xml_bytes, book_id)
            total_words += count
            print(f"{count:,} words")
        else:
            print("SKIPPED")

    # Summary
    print("\n── Summary ──────────────────────────────")
    cur = conn.execute("SELECT COUNT(*) FROM verse_words")
    print(f"  Total words (OT+NT): {cur.fetchone()[0]:,}")

    cur = conn.execute("""
        SELECT COUNT(*) FROM verse_words vw
        JOIN verses v ON vw.verse_id = v.verse_id
        WHERE v.book_id <= 39
    """)
    print(f"  Hebrew OT words: {cur.fetchone()[0]:,}")

    cur = conn.execute("""
        SELECT COUNT(*) FROM verse_words WHERE strongs_id IS NOT NULL
    """)
    print(f"  Words with Strong's: {cur.fetchone()[0]:,}")

    # Spot check Genesis 1:1
    cur = conn.execute("""
        SELECT vw.position, vw.word, vw.strongs_id, vw.grammar,
               s.transliteration, s.definition
        FROM verse_words vw
        JOIN verses v ON vw.verse_id = v.verse_id
        LEFT JOIN strongs s ON vw.strongs_id = s.strongs_id
        WHERE v.book_id = 1 AND v.chapter = 1 AND v.verse = 1
        ORDER BY vw.position
        LIMIT 5
    """)
    rows = cur.fetchall()
    if rows:
        print(f"\n  Spot check Genesis 1:1 (first 5 words):")
        for pos, word, sid, gram, xlit, defn in rows:
            short_def = (defn or "")[:40]
            print(f"    {pos}. {word:<12} {str(sid):<8} {xlit or '':<12} {short_def}")

    db_size = os.path.getsize(DB_PATH) / 1024 / 1024
    print(f"\n  Final DB size: {db_size:.2f} MB")

    conn.close()
    print(f"\n✓ Hebrew OT data saved to {DB_PATH}")
    print("\n── All done! ─────────────────────────────")
    print("  bible.sqlite is ready to bundle into Xcode.")
    print("  Next step: drag bible.sqlite into your Xcode project.")


if __name__ == "__main__":
    main()
