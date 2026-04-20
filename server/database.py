"""SQLite schema and helpers for anki-mate."""

import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parent / "data" / "anki_mate.db"

SCHEMA = """
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS batch (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS word (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id INTEGER NOT NULL REFERENCES batch(id) ON DELETE CASCADE,
    word TEXT NOT NULL,
    word_type TEXT NOT NULL DEFAULT '',
    meaning TEXT NOT NULL,
    example_1 TEXT NOT NULL DEFAULT '',
    example_2 TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS paragraph (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id INTEGER NOT NULL REFERENCES batch(id) ON DELETE CASCADE,
    paragraph TEXT NOT NULL DEFAULT ''
);
"""


def get_connection() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db() -> None:
    with get_connection() as conn:
        conn.executescript(SCHEMA)
        conn.commit()
