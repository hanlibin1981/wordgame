#!/usr/bin/env python3
"""Fill missing sentences using Free Dictionary API with parallel requests."""

import json
import sqlite3
import os
import time
import urllib.request
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed

DB_PATH = os.path.expanduser("~/Library/Application Support/WordGame/wordgame.db")
MAX_WORKERS = 20  # parallel requests

def fetch_example(word: str) -> tuple[str, str | None]:
    """Returns (word, sentence or None)"""
    url = f"https://api.dictionaryapi.dev/api/v2/entries/en/{urllib.parse.quote(word.strip())}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
        for entry in data:
            for meaning in entry.get("meanings", []):
                for defn in meaning.get("definitions", []):
                    example = defn.get("example")
                    if example:
                        return (word, example.strip())
    except Exception:
        pass
    return (word, None)

def main():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute("SELECT id, word FROM words WHERE sentence IS NULL OR sentence = ''")
    rows = cur.fetchall()
    print(f"Words needing sentences: {len(rows)}")

    # Deduplicate words (same word may appear multiple times in DB)
    unique_words = list({r[1]: r for r in rows}.values())
    print(f"Unique words: {len(unique_words)}")

    results: dict[str, str] = {}  # word → sentence
    updated = 0
    failed = 0
    total = len(unique_words)

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        future_to_word = {executor.submit(fetch_example, word): word for _, word in unique_words}
        for future in as_completed(future_to_word):
            word, sentence = future.result()
            if sentence:
                results[word] = sentence

            done = len(results) + failed
            if (done) % 200 == 0:
                print(f"[{done}/{total}] Found: {len(results)}, Not found: {failed}", flush=True)

    # Batch update DB
    cur.execute("SELECT id, word FROM words WHERE sentence IS NULL OR sentence = ''")
    all_rows = cur.fetchall()
    updated = 0
    for word_id, word in all_rows:
        sentence = results.get(word)
        if sentence:
            cur.execute("UPDATE words SET sentence = ? WHERE id = ?", (sentence, word_id))
            updated += 1

    conn.commit()

    cur.execute("SELECT COUNT(*) FROM words WHERE sentence IS NULL OR sentence = ''")
    remaining = cur.fetchone()[0]
    print(f"\nDone! Updated: {updated}, Remaining (no API entry): {remaining}")
    conn.close()

if __name__ == "__main__":
    main()
