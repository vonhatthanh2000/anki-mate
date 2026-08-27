# ADR 0013: Persist lessons and progress, not source media

Status: Accepted

## Context

The learner wants to reopen lessons, continue exercises, and know which items have already been exported to Anki. Retaining downloaded video or extracted audio is unnecessary after transcription and creates storage and content-handling concerns.

## Decision

Automatically save transcript lessons and learning progress to Supabase.

Persist:

- Source URL and identifying platform metadata
- Cleaned transcript and Meaning Overview
- Selected language items and analysis
- Generated exercises
- Learner answers, AI feedback, and completion state
- Per-item Anki export state

Do not persist downloaded video or extracted audio. Delete temporary media after transcription or failure cleanup.

## Consequences

- Lessons can be resumed and reviewed.
- The database schema needs lesson, item, exercise, attempt, and export state concepts.
- Media cleanup remains independent from database persistence.
- Reanalysis and edit/version behavior still require a decision.

