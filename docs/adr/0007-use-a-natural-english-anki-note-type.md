# ADR 0007: Use a Natural English Anki note type

Status: Accepted

## Context

The existing BoostVocab note schema contains Word, Meaning, Word type, Example 1, and Example 2. Treating collocations, slang, idioms, phrasal verbs, and grammar patterns as individual words would lose category and source context or overload unrelated fields.

## Decision

Create a separate Natural English Anki note type for transcript lesson exports.

Reuse the existing BoostVocab-style add-to-Anki interaction and shared AnkiConnect infrastructure, but map lesson items to fields designed for expressions and patterns:

- Expression or pattern
- Category
- Meaning and usage
- Original transcript example
- New natural example
- CEFR estimate
- Source URL

## Consequences

- Transcript-derived cards preserve authentic context and work for grammar as well as lexical items.
- The app needs note-type detection or setup guidance for Natural English.
- Export code should share transport and error handling with BoostVocab while keeping field mapping separate.
- Existing BoostVocab cards and decks remain unchanged.

