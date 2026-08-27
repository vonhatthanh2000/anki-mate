# ADR 0017: Cap v1 source duration at five minutes

Status: Accepted

## Context

The intended learning material is short-form video, normally 1–3 minutes. Longer sources increase acquisition time, transcription cost, transcript-review effort, analysis size, and lesson length.

## Decision

- Treat 1–3 minutes as the target source duration.
- Warn the learner when a source is longer than three minutes.
- Enforce a five-minute maximum in the first version.

## Consequences

- Processing cost and lesson scope remain bounded.
- Slightly oversized short-form videos still work.
- Sources longer than five minutes need a clear validation error.
- Selecting excerpts from longer videos is not part of this decision and would require a later design.

