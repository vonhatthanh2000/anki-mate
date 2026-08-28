# ADR 0021: Format URL transcripts for readable review

Status: Accepted

## Context

Some URL caption tracks arrive as a continuous block with little or no punctuation. Even when the words are accurate, the resulting paragraph is difficult to follow and correct in the transcript-review screen. Sending the text to an AI model solely to add punctuation would add cost and could silently rewrite the speaker's wording.

Manually entered text is learner-authored content and must not be reformatted without an explicit request.

## Decision

Format transcripts acquired from a URL into one sentence-like unit per line before presenting them for review.

- Use existing sentence-ending punctuation when it is available.
- When punctuation is absent, derive line boundaries locally from caption cues or timing information.
- Do not call OpenAI or another generative service for readability formatting.
- Preserve the source words and their order; formatting may change whitespace and line breaks only.
- Do not apply this formatting to pasted or manually edited transcript text.
- The learner may edit the formatted result before pressing Analyze, after which it becomes the approved transcript.

## Consequences

- URL-derived transcripts are easier to scan and correct.
- Caption boundaries are only an approximation of sentence boundaries when punctuation is missing.
- The formatter cannot invent commas or periods that the source captions do not provide.
- Manual input remains untouched.
- Transcript-span offsets continue to be calculated from the learner-approved, formatted transcript supplied to analysis.
