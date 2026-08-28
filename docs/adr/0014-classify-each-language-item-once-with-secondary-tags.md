# ADR 0014: Classify each language item once with secondary tags

Status: Accepted

Minimum-count language is superseded by ADR 0022; classification and upper-bound decisions remain accepted.

## Context

Natural language categories overlap. An expression may reasonably be both an idiom and a collocation, or both a phrasal verb and slang. Rendering one copy per category would duplicate explanations, exercises, and Anki notes.

## Decision

Represent each selected transcript span as one language item with:

- One primary category used for lesson organization
- Zero or more secondary category tags
- One shared analysis, practice set, and Anki export state

## Consequences

- The learner sees no duplicate items.
- Classification nuance is retained through secondary tags.
- Ranking and the 10-item upper limit apply to unique items.
- The data model needs a primary category plus a collection of secondary categories.
