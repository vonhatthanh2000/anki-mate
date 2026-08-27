# ADR 0016: Limit transcript lessons to English sources

Status: Accepted

## Context

The feature is designed to help one learner improve English listening and natural English usage. Supporting arbitrary source languages would broaden transcription, analysis, explanation, and exercise behavior without serving the stated learning goal.

## Decision

Generate transcript lessons only for sources spoken primarily in English.

Allow occasional code-switching to remain visible in the transcript for context, but do not extract non-English fragments as language items. Stop with a clear message when the source is predominantly non-English.

## Consequences

- Transcription should detect or estimate the primary spoken language.
- The analyzer can optimize its prompts and schema for English.
- Mixed-language sources need a threshold or model judgment for determining whether English is primary.
- Non-English fragments are preserved rather than silently deleted.

