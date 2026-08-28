# Transcript Lessons — Domain Model

## Core workflow

`Source submitted → acquiring transcript → transcript review → analyzing → lesson ready → independent replay/shadowing`

Acquisition and analysis can fail and be retried independently. Analysis consumes only the learner-approved transcript.

## Persisted concepts

### Source video

Identifies the YouTube or TikTok source through its canonical URL, platform, title when available, duration, and primary language.

### Approved transcript

The complete English transcript after learner review. It is the authoritative source text for one lesson and retains enough structure to connect highlighted spans to language items.

### Transcript lesson

The saved aggregate for one approved transcript. It owns the Meaning Overview, language items, exercises, attempts, and source link.

### Meaning Overview

The concise discourse-level explanation of the source's message, supporting ideas, tone, register, implications, and necessary context.

### Language item

A unique selected span in the approved transcript. It contains:

- Expression or grammar pattern
- Source span and excerpt
- Primary category and secondary category tags
- Meaning and usage
- Estimated CEFR level
- Selection rationale
- New natural example
- Optional targeted Vietnamese gloss
- Practice priority

### Exercise

A recognition or typed production prompt owned by a language item. Only the 3–5 strongest reusable items require exercises.

### Exercise attempt

The learner's typed answer plus AI feedback, suggested revision, and completion state.

### Anki export

The export state and resulting Anki note identifier for one language item. A unique relationship prevents accidental duplicate export.

## Transient concepts

### Acquisition job

Tracks the local attempt to obtain captions or media and produce a transcript. It owns temporary paths and cleanup responsibility but is not lesson content.

For URL-derived captions, the acquisition job also produces a readability-formatted transcript for review. It derives one sentence-like unit per line from existing punctuation, caption cues, or timing boundaries without using a generative model or changing the source words. Manual transcript input bypasses this formatting.

### Temporary media

Downloaded video or extracted audio used during acquisition. It must not be persisted to Supabase and should be deleted after transcription or failure handling.

## Relationships

- One source video can identify one or more acquisition attempts.
- One approved transcript produces one transcript lesson in v1.
- One transcript lesson owns one Meaning Overview and 6–10 unique language items.
- One language item may own recognition and production exercises.
- One exercise may have multiple saved attempts.
- One language item has at most one successful Natural English Anki export.

## Invariants

- A source is primarily English and no longer than five minutes.
- Analysis cannot begin before transcript approval.
- URL-derived caption formatting may change whitespace and line breaks only; source words and their order remain unchanged.
- Manually entered transcript text is not automatically reformatted.
- Language items reference exact spans in the approved transcript.
- A lesson contains no more than 10 unique language items.
- Categories may be empty; items are never invented to fill them.
- Each item has exactly one primary category.
- Only 3–5 items are selected for active practice.
- Generated analysis is read-only in v1.
- Source media is never part of persisted lesson state.
- Replay and shadowing completion are not tracked.
