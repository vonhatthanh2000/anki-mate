# ADR 0010: Anchor the lesson in a highlighted transcript

Status: Accepted

## Context

A categorized list of extracted expressions can lose the video's argument, story, and surrounding context. The learner wants to understand the source deeply before listening again.

## Decision

Show the complete cleaned transcript as the lesson anchor and highlight every selected language item inline.

Allow a highlight to open or navigate to its detailed analysis. Place the focused 6–10-item lesson after the transcript.

Each selected item includes its primary category, meaning and usage, original source excerpt, estimated CEFR level, selection rationale, and a new natural example. The 3–5 most reusable items also include practice.

## Consequences

- Extracted language remains connected to the source's meaning.
- Transcript cleanup must preserve the speaker's actual wording and item offsets.
- The data model needs stable links between transcript spans and lesson items.
- The interface needs inline highlighting and detail navigation.

