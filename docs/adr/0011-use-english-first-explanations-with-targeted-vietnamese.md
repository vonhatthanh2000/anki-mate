# ADR 0011: Use English-first explanations with targeted Vietnamese

Status: Accepted

## Context

The learner needs enough support to understand language above B2 while remaining immersed in English. Full bilingual output could make Vietnamese the default reading path and weaken direct comprehension of natural English.

## Decision

Write lesson explanations and feedback in clear English.

Add a short Vietnamese gloss only when a sentence is unusually difficult or needs sentence-level structural analysis. Do not translate the complete transcript.

## Consequences

- The lesson preserves English immersion.
- Difficult passages can still be clarified precisely and efficiently.
- The analyzer must decide when Vietnamese support is warranted rather than producing it for every item.
- The UI and data model should treat Vietnamese support as optional.

