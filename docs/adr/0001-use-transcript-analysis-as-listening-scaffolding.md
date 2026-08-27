# ADR 0001: Use transcript analysis as listening scaffolding

Status: Accepted

## Context

The learner wants to move beyond B2 and improve natural English through authentic short videos. A transcript analyzer could easily become a passive vocabulary report, which would not directly serve the learner's listening goal.

## Decision

Structure the feature as a listening-comprehension loop:

1. Analyze the transcript of a 1–3 minute source video.
2. Explain language that unlocks the video's meaning.
3. Provide active practice for important or commonly reusable language.
4. Let the learner send selected language into the existing BoostVocab/Anki workflow.
5. Return the learner to the source video for another listen.

Transcript analysis is scaffolding, not the final learning outcome.

## Consequences

- Lesson generation must prioritize comprehension and reuse rather than exhaustive extraction.
- The experience needs a clear transition back to video playback.
- Practice and Anki export should be selective.
- Success should eventually measure improved understanding on a later listen, not the number of extracted items.

