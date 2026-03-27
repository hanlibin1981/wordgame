#!/usr/bin/env python3
"""Generate simple template-based example sentences for remaining words."""

import sqlite3
import os
import re

DB_PATH = os.path.expanduser("~/Library/Application Support/WordGame/wordgame.db")

# Templates for different word patterns
TEMPLATES = [
    "Remember to {word} every day.",
    "Practice makes perfect: {word}.",
    "Learning to {word} takes time.",
    "The word '{word}' is useful in daily life.",
    "Can you use '{word}' in a sentence?",
    "Study the meaning of '{word}' carefully.",
    "Review '{word}' regularly to remember it.",
    "The teacher explained '{word}' in class.",
    "Understanding '{word}' is important.",
    "Try to memorize '{word}' today.",
]

# Templates for nouns
NOUN_TEMPLATES = [
    "The {word} is commonly used in English.",
    "What is a {word}?",
    "Do you know the meaning of {word}?",
    "The {word} is an important concept.",
    "Let's learn the word '{word}'.",
]

# Templates for adjectives
ADJ_TEMPLATES = [
    "This is an {word} example.",
    "Something that is {word} is interesting.",
    "The {word} situation needs attention.",
]

# Templates for verb-like
VERB_TEMPLATES = [
    "Remember to {word} every day.",
    "Try to {word} when you can.",
    "It is important to {word} regularly.",
]

# Templates for phrases (multi-word entries)
PHRASE_TEMPLATES = [
    "Pay attention to '{word}' in daily use.",
    "The phrase '{word}' is commonly used.",
    "Learn how to use '{word}' correctly.",
]

def classify_word(word: str) -> str:
    """Roughly classify word type."""
    w = word.lower()
    if ' ' in word or '-' in word or '/' in word:
        return 'phrase'
    if w.endswith('tion') or w.endswith('sion') or w.endswith('ment') or w.endswith('ness'):
        return 'noun'
    if w.endswith('ly') or w.endswith('ful') or w.endswith('ous') or w.endswith('ive'):
        return 'adj'
    if w.endswith('ing') or w.endswith('ed') or w.endswith('ate') or w.endswith('ify'):
        return 'verb'
    return 'generic'

def generate_sentence(word: str) -> str:
    """Generate a simple example sentence for a word."""
    w_type = classify_word(word)
    templates = {
        'phrase': PHRASE_TEMPLATES,
        'noun': NOUN_TEMPLATES,
        'adj': ADJ_TEMPLATES,
        'verb': VERB_TEMPLATES,
        'generic': TEMPLATES,
    }
    import random
    for t in random.sample(templates.get(w_type, TEMPLATES), len(templates.get(w_type, TEMPLATES))):
        sentence = t.format(word=word)
        # Basic validation
        if len(sentence) > 10 and len(sentence) < 150:
            return sentence
    return f"Study the word '{word}' carefully."

def main():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute("SELECT id, word FROM words WHERE sentence IS NULL OR sentence = ''")
    rows = cur.fetchall()
    print(f"Generating sentences for {len(rows)} words...")

    updated = 0
    for word_id, word in rows:
        sentence = generate_sentence(word)
        cur.execute("UPDATE words SET sentence = ? WHERE id = ?", (sentence, word_id))
        updated += 1

    conn.commit()

    cur.execute("SELECT COUNT(*) FROM words WHERE sentence IS NULL OR sentence = ''")
    remaining = cur.fetchone()[0]
    print(f"Done! Generated: {updated}, Remaining: {remaining}")
    conn.close()

if __name__ == "__main__":
    main()
