"""
Bible App - Data Pipeline
Step 2: Strong's Concordance → SQLite

Downloads Strong's Greek and Hebrew dictionaries from openscriptures/strongs
and imports them into bible.sqlite.

Run AFTER build_bible_db.py:
    python3 import_strongs.py

Requires: bible.sqlite in the same folder
"""

import json
import sqlite3
import urllib.request
import re
import os

# ── Config ─────────────────────────────────────────────────────────────────────

DB_PATH = "bible.sqlite"
BASE_URL = "https://raw.githubusercontent.com/openscriptures/strongs/master"

# These .js files are JavaScript assignments wrapping a JSON object.
# We strip the JS wrapper and parse the JSON directly.
GREEK_URL  = f"{BASE_URL}/greek/strongs-greek-dictionary.js"
HEBREW_URL = f"{BASE_URL}/hebrew/strongs-hebrew-dictionary.js"

# ── Helpers ────────────────────────────────────────────────────────────────────

def fetch_strongs_js(url):
    """Download a Strong's .js file and return parsed dict."""
    print(f"  Downloading {url.split('/')[-1]}...", end=" ", flush=True)
    with urllib.request.urlopen(url) as r:
        raw = r.read().decode("utf-8")

    # The file looks like: var strongsGreekDictionary = { "G1": {...}, ... };
    # Strip the JS variable assignment wrapper to get pure JSON.
    match = re.search(r'\{.*\}', raw, re.DOTALL)
    if not match:
        raise ValueError("Could not find JSON object in file")
    data = json.loads(match.group(0))
    print(f"{len(data):,} entries")
    return data


def extract_definition(entry):
    """Pull a clean plain-text definition from a Strong's entry dict."""
    # The 'strongs_def' key holds the main definition
    defn = entry.get("strongs_def", "") or ""
    # Also grab KJV usage note if available
    kjv = entry.get("kjv_def", "") or ""
    if kjv:
        defn = defn.rstrip(". ") + ". KJV: " + kjv
    return defn.strip()


def import_language(conn, data, language, prefix):
    """Insert all entries for one language into the strongs table."""
    rows = []
    for raw_id, entry in data.items():
        # Normalise key: G1 → G1, H1 → H1 (already prefixed in these files)
        strongs_id = raw_id.strip()
        if not strongs_id.startswith(prefix):
            strongs_id = prefix + strongs_id

        lemma           = entry.get("lemma", "") or ""
        xlit            = entry.get("xlit", "")  or entry.get("translit", "") or ""
        pron            = entry.get("pron", "")  or ""
        definition      = extract_definition(entry)
        part_of_speech  = entry.get("pos", "")   or ""
        derivation      = entry.get("derivation", "") or entry.get("strongs_derivation", "") or ""

        rows.append((
            strongs_id, language, lemma, xlit, pron,
            definition, part_of_speech, derivation
        ))

    conn.executemany("""
        INSERT OR REPLACE INTO strongs
            (strongs_id, language, lemma, transliteration, pronunciation,
             definition, part_of_speech, origin)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, rows)
    conn.commit()
    return len(rows)


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    if not os.path.exists(DB_PATH):
        print(f"✗ {DB_PATH} not found. Run build_bible_db.py first.")
        return

    conn = sqlite3.connect(DB_PATH)
    print("Importing Strong's dictionaries...\n")

    # Greek
    greek_data = fetch_strongs_js(GREEK_URL)
    greek_count = import_language(conn, greek_data, "greek", "G")
    print(f"  ✓ Greek entries inserted: {greek_count:,}")

    # Hebrew
    hebrew_data = fetch_strongs_js(HEBREW_URL)
    hebrew_count = import_language(conn, hebrew_data, "hebrew", "H")
    print(f"  ✓ Hebrew entries inserted: {hebrew_count:,}")

    # Summary
    print("\n── Summary ──────────────────────────────")
    cur = conn.execute("SELECT language, COUNT(*) FROM strongs GROUP BY language")
    for lang, count in cur.fetchall():
        print(f"  {lang.capitalize()}: {count:,} entries")

    # Spot check
    cur = conn.execute("""
        SELECT strongs_id, lemma, transliteration, definition
        FROM strongs WHERE strongs_id = 'G3056'
    """)
    row = cur.fetchone()
    if row:
        print(f"\n  Spot check G3056 (logos):")
        print(f"    Lemma:  {row[1]}")
        print(f"    Xlit:   {row[2]}")
        print(f"    Def:    {row[3][:80]}...")

    conn.close()
    print(f"\n✓ Strong's data saved to {DB_PATH}")
    print("\nNext: python3 import_greek_nt.py")


if __name__ == "__main__":
    main()
