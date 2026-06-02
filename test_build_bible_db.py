import json
import sqlite3
import unittest

from build_bible_db import create_schema, insert_book


class InsertBookNormalizationTests(unittest.TestCase):
    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        create_schema(self.conn)

    def tearDown(self):
        self.conn.close()

    def _insert_sample(self, verses):
        data = {"chapters": [{"verses": verses}]}
        insert_book(self.conn, 1, "Genesis", "OT", data)
        cur = self.conn.execute(
            "SELECT verse, text FROM verses WHERE book_id = 1 AND chapter = 1 ORDER BY verse"
        )
        return cur.fetchall()

    def test_normalizes_string_and_dict_verse_text(self):
        rows = self._insert_sample(
            [
                " In the beginning ",
                {"text": " Let there be light "},
                {"verse": " And God saw the light "},
                {"content": " And God called the light Day "},
            ]
        )

        self.assertEqual(
            rows,
            [
                (1, "In the beginning"),
                (2, "Let there be light"),
                (3, "And God saw the light"),
                (4, "And God called the light Day"),
            ],
        )

    def test_falls_back_to_json_for_unknown_dict_shape(self):
        rows = self._insert_sample([{"unexpected": "value"}])
        self.assertEqual(rows[0][1], json.dumps({"unexpected": "value"}, ensure_ascii=False))

    def test_coerces_non_string_non_dict_values(self):
        rows = self._insert_sample([42, None])
        self.assertEqual(rows, [(1, "42"), (2, "None")])


if __name__ == "__main__":
    unittest.main()
