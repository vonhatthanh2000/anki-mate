# ADR 0015: Require transcript approval before analysis

Status: Accepted

## Context

Speech-to-text can mishear names, slang, reduced speech, or fast delivery. If analysis starts immediately, those errors can become incorrect explanations, exercises, and Anki notes.

## Decision

Separate transcript acquisition from lesson analysis:

1. Acquire or generate the transcript.
2. Show the complete transcript in an editable review screen.
3. Wait for the learner to press Analyze.
4. Generate the lesson from the learner-approved transcript.

## Consequences

- The learner controls the source text used by the analyzer.
- An additional explicit step is added between URL submission and lesson generation.
- Transcription and analysis have separate loading, error, and retry states.
- Analysis cost is not incurred until transcript approval.
- The approved transcript, rather than raw speech-to-text output, becomes the saved lesson source.

