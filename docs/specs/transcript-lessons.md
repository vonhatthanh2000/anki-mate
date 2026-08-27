# Add Transcript Lessons for Deep Weekly English Study

## Problem Statement

The learner feels plateaued at CEFR B2. Authentic short YouTube and TikTok videos contain natural vocabulary, idioms, phrasal verbs, collocations, slang, and grammar patterns that are difficult to notice or understand through listening alone.

The learner plans to study one video per week. They need a focused way to obtain and correct the English transcript, understand the speaker's overall meaning, identify a small number of high-value language items, practice the most reusable items, and retain selected material in Anki. Video replay and shadowing will happen independently on YouTube or TikTok.

BoostVocab's vocabulary-only workflow and Anki note shape cannot adequately represent multi-word expressions, grammar patterns, overlapping categories, or authentic source context.

## Solution

Add Transcript Lessons as a feature alongside BoostVocab in the native macOS app.

The learner pastes a YouTube or TikTok URL for a primarily English video. The app performs best-effort local transcript acquisition, using speech-to-text when media must be transcribed. It then stops and presents the complete transcript for review and correction. Analysis begins only after the learner presses Analyze.

The generated lesson starts with a concise Meaning Overview and shows the complete approved transcript with high-value language highlighted inline. It selects 6–10 unique items across Vocabulary, Idiom, Phrasal verb, Collocation, Slang, and Grammar pattern without forcing every category to appear. The 3–5 strongest reusable items receive contextual recognition and typed production practice with concise AI feedback.

Lessons and progress are saved to Supabase. Selected language items can be exported once through AnkiConnect to a dedicated Natural English note type. Downloaded media and extracted audio are temporary and are deleted after transcription. The lesson ends with a clear link back to the original source for independent replay and shadowing.

## User Stories

1. As the learner, I want to see Transcript Lessons alongside BoostVocab, so that I can choose transcript study from the app's home screen.
2. As the learner, I want to paste a YouTube URL, so that I can study natural English from a YouTube video.
3. As the learner, I want to paste a TikTok URL, so that I can study natural English from a TikTok video.
4. As the learner, I want the app to validate the submitted URL, so that malformed or unsupported sources fail clearly.
5. As the learner, I want the app to recognize the source platform, so that acquisition uses the correct behavior.
6. As the learner, I want the app to treat 1–3 minutes as the ideal source length, so that weekly lessons remain focused.
7. As the learner, I want a warning for videos longer than three minutes, so that I understand the lesson may be denser than intended.
8. As the learner, I want videos longer than five minutes rejected in v1, so that processing and lesson scope remain bounded.
9. As the learner, I want the app to analyze only primarily English sources, so that every lesson serves my English-learning goal.
10. As the learner, I want occasional non-English fragments preserved for context, so that code-switching does not damage the transcript.
11. As the learner, I want non-English fragments excluded from language-item analysis, so that the lesson remains focused on English.
12. As the learner, I want a clear error for a predominantly non-English source, so that I know why no lesson was generated.
13. As the learner, I want the app to obtain available source text when possible, so that I can avoid unnecessary transcription.
14. As the learner, I want the app to perform speech-to-text when usable captions are unavailable, so that URL-only input works for more personal study sources.
15. As the learner, I want local media upload as an acquisition fallback, so that I can continue when URL acquisition fails.
16. As the learner, I want manual transcript paste as a lightweight fallback, so that platform restrictions do not prevent study.
17. As the learner, I want acquisition and transcription errors distinguished from analysis errors, so that I know which step to retry.
18. As the learner, I want downloaded media and extracted audio deleted after transcription, so that source media is not retained unnecessarily.
19. As the learner, I want temporary media cleaned up after failures where possible, so that failed attempts do not leave unwanted files.
20. As the learner, I want to see the complete acquired transcript before analysis, so that I can catch transcription mistakes.
21. As the learner, I want to edit the transcript before analysis, so that names, slang, and fast speech are represented correctly.
22. As the learner, I want analysis to wait for an explicit Analyze action, so that an unreviewed transcript never contaminates the lesson.
23. As the learner, I want the approved transcript to become the authoritative lesson source, so that saved analysis corresponds to the text I reviewed.
24. As the learner, I want visible progress during acquisition, transcription, and analysis, so that long-running work does not appear frozen.
25. As the learner, I want each processing stage to be retryable after a recoverable failure, so that I do not need to restart unnecessarily.
26. As the learner, I want every lesson to begin with a short Meaning Overview, so that I understand the video's overall message before studying details.
27. As the learner, I want a 3–5 sentence summary, so that I can quickly confirm the main content.
28. As the learner, I want the speaker's main point and supporting ideas identified, so that I can follow the structure of the message.
29. As the learner, I want tone and register identified, so that I understand whether the English is casual, motivational, academic, humorous, or otherwise context-specific.
30. As the learner, I want brief implied meaning and necessary cultural context explained, so that unstated assumptions do not block comprehension.
31. As the learner, I want source assertions attributed to the speaker, so that an unverified claim is not presented as fact.
32. As the learner, I want conceptual explanations kept short, so that the feature remains a language lesson rather than a research report.
33. As the learner, I want to see the complete approved transcript in the lesson, so that extracted language remains connected to the video's meaning.
34. As the learner, I want selected language highlighted inline, so that I can see exactly where and how it was used.
35. As the learner, I want a highlight to navigate to its detailed analysis, so that moving between context and explanation is easy.
36. As the learner, I want no more than 6–10 selected language items, so that one weekly lesson remains manageable.
37. As the learner, I want items ranked by comprehension value and reusability, so that I study the most useful language first.
38. As the learner, I want B2–C2 language prioritized, so that the lesson helps me progress beyond my current plateau.
39. As the learner, I want a deceptively simple item included when its contextual use is subtle or essential, so that a CEFR estimate does not hide valuable natural English.
40. As the learner, I want every selected item to explain why it was chosen, so that the analysis does not feel arbitrary.
41. As the learner, I want empty categories permitted, so that the analyzer does not invent weak material to fill a template.
42. As the learner, I want each language item stored once, so that overlapping classifications do not duplicate content.
43. As the learner, I want one primary category and optional secondary tags, so that overlapping classifications remain visible without duplication.
44. As the learner, I want each item to explain its meaning and usage in context, so that I can understand how native speakers use it.
45. As the learner, I want the original source excerpt attached to each item, so that I retain its authentic context.
46. As the learner, I want an estimated CEFR label, so that I can judge how advanced an item may be.
47. As the learner, I want CEFR presented as an estimate rather than a certification, so that uncertain labels are not misleading.
48. As the learner, I want a new natural example for each item, so that I can see how it transfers beyond the video.
49. As the learner, I want clear English explanations by default, so that the lesson itself supports English immersion.
50. As the learner, I want a short Vietnamese gloss only for a genuinely difficult sentence or sentence-level analysis, so that difficult language becomes clear without translating the whole lesson.
51. As the learner, I want the complete transcript to remain untranslated, so that I practice understanding English directly.
52. As the learner, I want the 3–5 most reusable items selected for practice, so that exercises focus on language worth retrieving actively.
53. As the learner, I want contextual recognition exercises, so that I can check whether I understand appropriate meaning and usage.
54. As the learner, I want typed paraphrase or original-example tasks, so that I practice producing natural English.
55. As the learner, I want production feedback on meaning, correctness, appropriateness, and naturalness, so that I learn more than whether an answer is technically grammatical.
56. As the learner, I want concise correction explanations and a natural revision, so that I know how to improve my answer.
57. As the learner, I want exercise attempts saved, so that I can continue a weekly lesson later.
58. As the learner, I want every generated lesson saved automatically, so that I can revisit it during the week.
59. As the learner, I want saved lessons to preserve the approved transcript, Meaning Overview, language items, exercises, attempts, and feedback, so that the learning experience is resumable.
60. As the learner, I want Anki export state saved for each item, so that I do not accidentally create duplicate notes.
61. As the learner, I want to browse and reopen saved Transcript Lessons, so that I can continue or review my weekly study.
62. As the learner, I want to export a selected item with one action, so that Anki retention fits naturally into the lesson.
63. As the learner, I want transcript items exported as Natural English notes rather than vocabulary-only notes, so that expressions and grammar patterns retain their meaning.
64. As the learner, I want the Natural English note to contain the expression or pattern, category, meaning and usage, original transcript example, new natural example, CEFR estimate, and source URL, so that the card remains useful outside the app.
65. As the learner, I want the app to reuse the reliable AnkiConnect behavior already used by BoostVocab, so that export remains familiar.
66. As the learner, I want a clear setup error when the Natural English note type or required fields are missing, so that I can correct Anki configuration.
67. As the learner, I want a clear error when Anki or AnkiConnect is unavailable, so that I know how to complete export.
68. As the learner, I want successful export to retain the returned Anki note identifier, so that the app can prevent accidental duplicates.
69. As the learner, I want a link back to the original YouTube or TikTok source, so that I can listen again after studying.
70. As the learner, I want replay and shadowing to remain self-directed, so that the app stays focused on transcript analysis.
71. As the learner, I want no microphone or pronunciation workflow, so that the feature does not expand into speech assessment.
72. As the learner, I want the generated analysis to be read-only in v1, so that the workflow remains simple and quality control happens through transcript approval.
73. As the learner, I want BoostVocab behavior to remain unchanged, so that the new feature does not disrupt my existing vocabulary workflow.
74. As the learner, I want one deep lesson to be more important than generating many lessons, so that the feature supports my one-video-per-week plan.

## Implementation Decisions

- Add Transcript Lessons as a second home-screen feature without changing BoostVocab's existing entry point or behavior.
- Introduce one deep `TranscriptLessonWorkflow` module as the primary interface for both SwiftUI callers and behavioral tests. The interface accepts workflow actions and returns a complete observable workflow snapshot.
- Keep URL validation, acquisition orchestration, transcript approval, analysis orchestration, persistence, exercise evaluation, cleanup status, and Anki export coordination behind the workflow module's interface.
- Model the visible workflow states as source entry, acquisition in progress, transcript review ready, analysis in progress, lesson ready, and recoverable or terminal failure. Acquisition and analysis failures remain distinguishable.
- Use injected ports only at true external seams: media/caption acquisition, OpenAI transcription and analysis, Supabase persistence, local temporary-file handling, and AnkiConnect. Production and test adapters make these seams real.
- Extend the existing bundled Python agent capability for media acquisition, speech-to-text, structured lesson analysis, and production-answer evaluation. Keep the Swift caller responsible for typed decoding, process lifecycle, cancellation, and user-facing error mapping.
- Treat URL acquisition as best-effort personal-use behavior rather than guaranteed platform integration.
- Canonicalize and validate YouTube and TikTok URLs before starting acquisition.
- Inspect source duration when possible. Warn above three minutes and reject above five minutes before expensive processing. If duration cannot be known until acquisition, enforce the cap as soon as it becomes known.
- Detect the primary spoken language before lesson analysis. Reject predominantly non-English sources; preserve occasional non-English fragments in the transcript but exclude them from item selection.
- Prefer usable acquired captions when available. Otherwise acquire temporary media and use speech-to-text. Offer authorized local media upload and manual transcript paste when URL acquisition fails.
- Store temporary artifacts in an isolated per-job directory. Perform cleanup after successful transcription, cancellation, and failure where possible. Never upload source media to Supabase.
- Return the complete acquired transcript to Swift before any lesson-analysis request.
- Permit transcript editing only during the review stage. The learner-approved text becomes the authoritative transcript.
- Require an explicit Analyze action. Do not automatically analyze after transcription.
- Require structured, schema-validated JSON from transcription-analysis processes. Treat malformed output as a retryable analysis failure rather than partially populating a lesson.
- Generate a concise Meaning Overview with a 3–5 sentence summary, main point, supporting ideas, tone, register, implications, and only necessary cultural context.
- Do not perform web research or fact-checking. Attribute unsupported assertions to the speaker and keep contextual explanation concise.
- Select 6–10 unique language items across Vocabulary, Idiom, Phrasal verb, Collocation, Slang, and Grammar pattern.
- Rank items by importance to source comprehension, frequency and reusability, and relevance to a B2 learner. Do not impose per-category quotas.
- Treat CEFR as an estimated ranking signal. Prioritize B2–C2 items but allow a lower-level item when its contextual use is subtle or essential. Include a selection rationale for every item.
- Represent each item once with exactly one primary category and zero or more secondary category tags.
- Preserve a stable transcript-span reference for every item so inline highlights remain connected to the approved transcript. Reject or repair analyzer output whose spans cannot be resolved safely.
- Store for each language item: expression or pattern, transcript span, source excerpt, primary category, secondary tags, meaning and usage, estimated CEFR level, selection rationale, new natural example, optional targeted Vietnamese gloss, practice priority, and Anki export state.
- Write explanations and feedback in clear English. Generate Vietnamese only as a short optional gloss for difficult sentence-level analysis; never translate the complete transcript.
- Generate both contextual recognition and typed production exercises for the 3–5 items with the highest practice priority.
- Evaluate typed production through the analysis adapter and return feedback on meaning, correctness, contextual appropriateness, and naturalness, including a concise explanation and natural revision.
- Make generated lesson analysis read-only in v1. Quality correction occurs by editing the transcript before analysis; analysis editing and analysis version history are not introduced.
- Add normalized Supabase storage for source metadata, transcript lessons, language items, exercises, exercise attempts, and Anki exports.
- Use foreign keys with cascading deletion for lesson-owned records. Keep successful Anki note identifiers and enforce at most one successful export per language item.
- Save the approved transcript and generated lesson automatically after successful analysis. Save exercise attempts and feedback as they occur.
- Add saved Transcript Lessons browsing and reopening alongside, but separate from, the existing saved BoostVocab batches.
- Add a generic Anki note-writing capability behind the existing AnkiConnect implementation so BoostVocab and Transcript Lessons share transport, availability checks, deck creation, response parsing, and error behavior while retaining separate field mappings.
- Define a Natural English note type with the exact fields Expression or pattern, Category, Meaning and usage, Original transcript example, New natural example, CEFR estimate, and Source URL.
- Detect missing Natural English note configuration and present actionable setup guidance. Do not modify or migrate the existing BoostVocab note type.
- Persist the successful Anki note identifier before reporting export complete. Repeated export actions for an already exported item return the existing state rather than creating another note.
- Open source links in the native YouTube or TikTok application when available, otherwise in the system browser. Do not embed playback.
- Update application packaging so every required Python dependency and local acquisition/transcription helper is available in the app bundle or produces a clear configuration error.
- Apply all database changes through new timestamped Supabase migrations; do not rewrite applied migrations.
- Preserve the existing personal-use credential model for v1 while ensuring API keys are not included in logs, persisted lesson records, or process error messages.

## Testing Decisions

- Add a Swift test target; the repository currently has no automated test target or test suite.
- Use the `TranscriptLessonWorkflow` interface as the primary and highest behavioral test seam. Tests send actions and assert returned workflow snapshots, persisted observable records, cleanup outcomes, and external calls without reaching into implementation state.
- A good test describes externally observable behavior and survives refactoring of SwiftUI views, Python process details, storage encoding, and internal orchestration.
- Use in-memory or mock adapters for true external dependencies: acquisition, transcription/analysis, Supabase, temporary media, and AnkiConnect.
- Test the complete successful behavior through the workflow seam: URL submission, transcript acquisition, learner correction, explicit approval, analysis, automatic persistence, exercise attempt, one-time Anki export, and source-link availability.
- Test that analysis is never called before the explicit Analyze action.
- Test URL validation for supported YouTube and TikTok forms and clear rejection of unsupported input.
- Test the three-minute warning and five-minute rejection, including duration discovered only after acquisition.
- Test primarily English acceptance, occasional code-switching preservation, non-English exclusion from items, and predominantly non-English rejection.
- Test caption success, speech-to-text fallback, local media fallback, transcript-paste fallback, and differentiated acquisition failures.
- Test temporary-media cleanup after success, cancellation, and failure. Assert behavior through the temporary-file adapter rather than implementation paths.
- Test that the approved edited transcript, not the raw acquired transcript, is supplied to analysis and saved.
- Test malformed or schema-invalid analyzer output as a retryable failure with no partial lesson persisted.
- Test Meaning Overview limits and attribution behavior using deterministic analyzer fixtures rather than asserting exact generative prose.
- Test item invariants: 6–10 unique items, no category quotas, exactly one primary category, optional secondary tags, resolvable transcript spans, and selection rationales.
- Test CEFR exception behavior through fixtures containing a subtle lower-level expression and assert that the rationale explains its inclusion.
- Test that Vietnamese glosses are optional and the complete transcript is never translated by the workflow contract.
- Test that only 3–5 items receive both recognition and production exercises.
- Test exercise-attempt persistence and observable feedback fields without asserting private prompt construction.
- Test lesson reopening returns the approved transcript, Meaning Overview, items, attempts, and Anki export state.
- Test Natural English field mapping at the Anki adapter contract, including special characters and multiline source excerpts.
- Test missing note type, Anki unavailable, AnkiConnect error, successful export, and duplicate-export prevention.
- Add focused contract tests for the bundled Python CLI JSON input/output and exit behavior. These complement rather than replace the workflow tests.
- Add focused Supabase adapter tests against a disposable or isolated test project when available; otherwise validate request/response contracts with a controlled URL transport adapter.
- Add a small number of SwiftUI state-rendering smoke tests only if practical. Do not make view hierarchy details the primary verification method.
- Preserve manual packaging verification for the app bundle: launch the packaged app, acquire one short source, transcribe, analyze, persist, reopen, and export to a test Anki profile.
- There is no direct automated-test prior art in the repository. Existing VocabAgent, Supabase, and AnkiConnect clients provide integration behavior to preserve, but not a test structure to copy.

## Out of Scope

- Embedded YouTube or TikTok playback
- Downloaded-video or extracted-audio retention
- Offline playback
- Voice recording
- Pronunciation assessment
- Spoken-answer evaluation
- Guided, tracked, or verified shadowing
- Full-transcript Vietnamese translation
- Support for predominantly non-English sources
- Sources longer than five minutes
- Selecting excerpts from longer videos
- Exhaustive extraction of every unfamiliar transcript fragment
- Fixed per-category quotas
- Fact-checking, external research, or citations
- Editing generated lesson analysis
- Analysis regeneration and version history
- Multiple learner profiles or distributed multi-user operation
- Goals, streaks, reminders, weekly scheduling, or habit tracking
- Automatic verification that the learner replayed or shadowed the source
- Changes to existing BoostVocab cards, note types, batches, or workflows

## Further Notes

- The expected usage is one deeply studied video per week. Optimize analysis quality, clarity, and resumability over throughput.
- Transcript analysis is listening scaffolding. The final learning activity is the learner's independent replay and shadowing on the source platform.
- URL acquisition depends on platform behavior and may break independently of transcription or analysis. Fallback inputs are part of the core workflow, not optional polish.
- YouTube and TikTok playback remain externally attributed and outside the app.
- CEFR labels are estimates and must not be presented as objective certification.
- Existing ADRs 0001–0019 and the Transcript Lessons domain glossary are normative context for implementation.
- The preferred test design uses one deep module and one primary seam. External adapters receive focused contract coverage; internal implementation details do not become separate test surfaces.
- The issue should receive only the `ready-for-agent` triage label when published.

