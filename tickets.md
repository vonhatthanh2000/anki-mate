# Transcript Lessons — Implementation Tickets

Parent spec: GitHub issue #3 — Add Transcript Lessons for Deep Weekly English Study

Status: Approved

## Dependency graph

- T1 → T2 → T3 → T4
- T2 → T5
- T1 → T6 → T7
- T3 + T4 + T5 + T7 → T8

## T1: Manual transcript to saved Meaning Overview

**Blocked by:** None (can start immediately)

**What to build:** Add the Transcript Lessons entry point and the first complete workflow: paste a transcript, review and edit it, explicitly request analysis, receive a concise Meaning Overview, and save the result. Introduce the deep `TranscriptLessonWorkflow` module as the shared interface used by SwiftUI and behavioral tests.

**Status:** implemented

- [x] Transcript Lessons appears alongside BoostVocab without changing BoostVocab behavior.
- [x] The learner can paste and edit a primarily English transcript.
- [x] Analysis never starts until the learner presses Analyze.
- [x] The analyzer returns a concise Meaning Overview containing the summary, main point, supporting ideas, tone, register, and only necessary context.
- [x] Unsupported claims are attributed to the speaker rather than presented as verified facts.
- [x] The approved transcript and Meaning Overview are saved to Supabase.
- [x] Acquisition, review, analysis, success, and failure are observable workflow states.
- [x] A Swift test target exercises the complete behavior through the workflow interface using test adapters.

## T2: Analyze and highlight high-value language

**Blocked by:** T1 — Manual transcript to saved Meaning Overview

**What to build:** Expand an analyzed lesson with a focused set of high-value language items connected to exact spans in the approved transcript. Show the transcript with inline highlights and navigate from each highlight to its explanation.

**Status:** implemented

- [x] A lesson contains 6–10 unique high-value items across Vocabulary, Idiom, Phrasal verb, Collocation, Slang, and Grammar pattern.
- [x] Categories may remain empty; the analyzer does not create weak items to fill quotas.
- [x] Each item has exactly one primary category and optional secondary category tags.
- [x] Each item includes meaning and usage, source excerpt, estimated CEFR level, selection rationale, and a new natural example.
- [x] B2–C2 items are prioritized while subtle or essential lower-level usage may be included with justification.
- [x] Short Vietnamese support appears only for difficult sentence-level analysis.
- [x] Every item resolves to a stable span in the approved transcript.
- [x] Selected language is highlighted inline and linked to its detailed analysis.
- [x] Language items and their analysis are saved with the lesson.
- [x] Workflow tests verify item limits, uniqueness, classification, span resolution, and persisted output.

## T3: Browse and resume saved Transcript Lessons

**Blocked by:** T2 — Analyze and highlight high-value language

**What to build:** Add a saved Transcript Lessons experience where the learner can browse previous lessons and reopen one with its approved transcript, Meaning Overview, selected language, and progress intact.

**Status:** implemented

- [x] Saved Transcript Lessons are browsable separately from BoostVocab batches.
- [x] Reopening a lesson restores source metadata, the approved transcript, Meaning Overview, and language items.
- [x] The complete transcript-to-item highlighting relationship survives persistence and reload.
- [x] Saved lesson loading and database errors are presented clearly.
- [x] Source media and extracted audio are never included in persisted lesson state.
- [x] Workflow tests verify saving, listing, reopening, and reconstruction of a complete lesson.

## T4: Practice reusable language with AI feedback

**Blocked by:** T3 — Browse and resume saved Transcript Lessons

**What to build:** Give the 3–5 strongest reusable language items both contextual recognition and typed production practice. Save attempts and return concise feedback that helps the learner use the language naturally.

**Status:** implemented

- [x] Exactly 3–5 high-priority items receive active practice.
- [x] Each practiced item includes a contextual recognition exercise.
- [x] Each practiced item includes a typed paraphrase or original-example task.
- [x] Production feedback covers meaning, correctness, contextual appropriateness, and naturalness.
- [x] Feedback includes a concise explanation and a natural suggested revision rather than only a score.
- [x] Attempts and feedback are saved and restored when the lesson is reopened.
- [x] No microphone, recording, pronunciation, or spoken-response behavior is introduced.
- [x] Workflow tests verify exercise selection, evaluation results, persistence, and resume behavior.

## T5: Export Natural English notes to Anki

**Blocked by:** T2 — Analyze and highlight high-value language

**What to build:** Let the learner export a selected language item once to a dedicated Natural English Anki note while preserving BoostVocab's existing note mapping and behavior.

**Status:** implemented

- [x] AnkiConnect transport, availability checks, deck creation, response parsing, and errors are shared behind a generic note-writing interface.
- [x] BoostVocab retains its existing field mapping and behavior.
- [x] Natural English notes contain Expression or pattern, Category, Meaning and usage, Original transcript example, New natural example, CEFR estimate, and Source URL.
- [x] Missing Natural English note type or fields produce actionable setup guidance.
- [x] Anki and AnkiConnect availability failures remain clear and recoverable.
- [x] A successful export saves the returned Anki note identifier.
- [x] Repeated export of the same language item does not create a duplicate note.
- [x] Tests verify both field mappings, special characters, multiline excerpts, errors, and duplicate prevention.

## T6: Acquire editable transcripts from video URLs

**Blocked by:** T1 — Manual transcript to saved Meaning Overview

**What to build:** Accept a YouTube or TikTok URL and obtain usable captions when available, then hand the result to the existing editable transcript-review stage. Keep manual transcript paste available when URL acquisition fails.

**Status:** implemented

- [x] Supported YouTube and TikTok URLs are validated, canonicalized, and associated with the correct platform.
- [x] Invalid and unsupported URLs fail before expensive processing.
- [x] Sources from one to three minutes proceed normally.
- [x] Sources longer than three minutes show a warning.
- [x] Sources longer than five minutes are rejected as soon as duration becomes known.
- [x] Primarily English sources are accepted and occasional code-switching is preserved for context.
- [x] Predominantly non-English sources are rejected before lesson analysis.
- [x] Usable captions populate the editable transcript-review state.
- [x] Analysis still waits for transcript review and the explicit Analyze action.
- [x] Acquisition errors are distinguished from analysis errors and offer manual transcript paste.
- [x] The lesson retains a link to the original source for independent replay and shadowing.
- [x] Workflow tests cover supported URL forms, duration rules, language handling, caption success, and fallback behavior.

## T7: Transcribe videos when captions are unavailable

**Blocked by:** T6 — Acquire editable transcripts from video URLs

**What to build:** Add best-effort personal-use media acquisition and authorized local-file upload, then generate a transcript with speech-to-text when usable captions are unavailable. Keep all media temporary and surface precise failure states.

**Status:** implemented

- [x] Caption failure can fall back to best-effort local media acquisition.
- [x] The learner can supply an authorized local audio or video file when URL acquisition fails.
- [x] Speech-to-text returns the complete transcript to the existing review stage.
- [x] Downloaded media and extracted audio live in an isolated per-job temporary location.
- [x] Temporary media is deleted after successful transcription.
- [x] Cleanup is attempted after failure and cancellation.
- [x] Acquisition and transcription errors are reported separately and remain retryable where appropriate.
- [x] Required acquisition and transcription dependencies are available to the packaged app or produce actionable configuration errors.
- [x] Logs and process errors do not expose API keys.
- [x] Workflow and adapter contract tests verify transcription fallback, local upload, cleanup, cancellation, malformed output, and error mapping.

## T8: Verify the packaged weekly-study workflow

**Blocked by:**

- T3 — Browse and resume saved Transcript Lessons
- T4 — Practice reusable language with AI feedback
- T5 — Export Natural English notes to Anki
- T7 — Transcribe videos when captions are unavailable

**What to build:** Integrate and verify the complete packaged macOS workflow for one deeply studied weekly video: URL, transcript review, analysis, persistence, practice, Anki export, and return to the original source for independent replay and shadowing.

**Status:** ready-for-agent

- [ ] A packaged build completes the full happy path from a supported URL to a saved lesson.
- [ ] Caption and speech-to-text acquisition paths both reach transcript review.
- [ ] The approved transcript produces a concise Meaning Overview and 6–10 valid highlighted language items.
- [ ] Practice attempts save and reload correctly.
- [ ] A selected item exports once as a Natural English note.
- [ ] The original source opens externally for replay and self-directed shadowing.
- [ ] Recoverable acquisition, transcription, analysis, persistence, and Anki errors can be retried at the correct stage.
- [ ] Temporary media is absent after success, failure, and cancellation verification.
- [ ] Packaged dependencies and credential loading work without exposing secrets.
- [ ] Existing BoostVocab creation, saved batches, enrichment, and Anki export continue to work.
- [ ] Automated tests pass and the packaged manual smoke test is documented.
