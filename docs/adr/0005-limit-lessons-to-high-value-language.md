# ADR 0005: Limit lessons to high-value language

Status: Accepted

## Context

A 1–3 minute transcript may contain many potentially teachable fragments. Exhaustive extraction would overwhelm the learner, while a fixed quota for every category would encourage weak or fabricated classifications.

## Decision

Select at most 6–10 language items per lesson across all categories combined.

Rank candidates by:

1. Importance to understanding the source video.
2. Frequency and reusability in natural English.
3. Relevance to a learner at B2 or above.

Do not impose per-category quotas. A category may be empty.

## Consequences

- Lessons stay short enough for focused study and replay.
- Category distribution reflects the source rather than a template.
- The analyzer needs to rank candidates, not merely classify them.
- The interface should explain that omitted categories had no high-value examples.

