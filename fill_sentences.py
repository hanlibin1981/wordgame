#!/usr/bin/env python3
"""Fill missing sentences for words from vocabulary JSON source files."""

import json
import sqlite3
import os

VOCAB_DIR = "/Users/mac/openclaw-projects/wordgame/WordGame/Resources/Vocabularies"
DB_PATH = os.path.expanduser("~/Library/Application Support/WordGame/wordgame.db")

def load_sentences_from_json(filepath):
    """Build a dict: (word_lower, meaning) → sentence"""
    sentences = {}
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
        for entry in data.get("words", []):
            word = entry.get("word", "").strip()
            sentence = entry.get("sentence")
            if word and sentence and sentence.strip():
                # Key by lowercased word (rough match)
                sentences[word.lower()] = sentence.strip()
                # Also index by the exact word
                sentences[word] = sentence.strip()
    except Exception as e:
        print(f"Error loading {filepath}: {e}")
    return sentences

def main():
    # Load all vocabulary JSON files
    all_sentences = {}
    for filename in os.listdir(VOCAB_DIR):
        if filename.endswith(".json"):
            path = os.path.join(VOCAB_DIR, filename)
            print(f"Loading {filename}...")
            all_sentences.update(load_sentences_from_json(path))

    print(f"Total sentences loaded from JSON: {len(all_sentences)}")

    # Connect to DB
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    # Find words missing sentences in DB
    cur.execute("SELECT id, word, meaning, sentence FROM words WHERE sentence IS NULL OR sentence = ''")
    rows = cur.fetchall()
    print(f"Words missing sentences in DB: {len(rows)}")

    updated = 0
    not_found = 0

    for row in rows:
        word_id, word, meaning, _ = row
        # Try exact match first, then case-insensitive
        sentence = all_sentences.get(word) or all_sentences.get(word.lower())

        if sentence:
            cur.execute("UPDATE words SET sentence = ? WHERE id = ?", (sentence, word_id))
            updated += 1
        else:
            not_found += 1

    conn.commit()
    print(f"\nUpdated: {updated}")
    print(f"Not found in JSON: {not_found}")

    # Verify
    cur.execute("SELECT COUNT(*) FROM words WHERE sentence IS NULL OR sentence = ''")
    remaining = cur.fetchone()[0]
    print(f"Remaining words without sentences: {remaining}")

    conn.close()

if __name__ == "__main__":
    main()
