# ADR 0020: Share BoostVocab control styling across Transcript Lessons

Status: Accepted

## Context

Transcript Lessons initially used native rounded macOS button styles. This made it feel visually separate from BoostVocab, whose controls use the app's coastal palette, square corners, strong ocean borders, and high-contrast labels.

## Decision

Transcript Lessons will use the same control language as BoostVocab:

- white action labels on cyan or ocean-filled rectangular controls;
- four-point ocean borders;
- the display font for action labels;
- light surfaces for editable text and longer reading content;
- reduced opacity, rather than a different component shape, for disabled controls.

This applies to navigation, acquisition, analysis, replay, practice, and Anki export actions.

## Consequences

- Transcript Lessons and BoostVocab read as parts of one product.
- Primary and secondary actions remain distinguishable through their fill shade while retaining the same geometry.
- Future Transcript Lessons actions should reuse `TranscriptLessonButtonStyle` instead of native bordered button styles.
