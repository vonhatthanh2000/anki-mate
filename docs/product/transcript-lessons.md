# Transcript Lessons — Product Discovery

Status: Ready for implementation planning

## Problem

The learner feels plateaued at CEFR B2 and wants to learn more natural spoken and written English from authentic YouTube and TikTok content.

## Proposed capability

Add a feature alongside BoostVocab that accepts a YouTube or TikTok URL, obtains the video's transcript, and turns it into a lesson.

The analysis should identify B2-and-above language in these categories:

- Vocabulary
- Idiom
- Phrasal verb
- Collocation
- Slang
- Grammar pattern

## Intended outcome

Help the learner speak and write English more naturally.

The primary skill being trained is listening comprehension. Transcript analysis is temporary scaffolding that helps the learner understand language above their current level before listening to the source again.

The expected cadence is one deeply studied video per week. The product optimizes for depth and clarity, not content volume, streaks, or rapid lesson generation.

## Agreed learning loop

1. The learner submits a YouTube or TikTok URL.
2. The system obtains or generates the transcript of a short video, normally 1–3 minutes long.
3. The learner reviews and may edit the transcript.
4. The learner explicitly presses Analyze.
5. The lesson explains language needed to understand the video's ideas deeply, with emphasis on grammar patterns, collocations, slang, and other important B2-and-above usage.
6. The 3–5 most reusable items receive both a contextual recognition exercise and an active production task.
7. The learner may send selected items through a BoostVocab-style action into a dedicated Natural English Anki note type.
8. After understanding the lesson, the learner returns to YouTube or TikTok and watches the original video again to strengthen listening comprehension.

Video playback remains on the source platform. The app focuses on transcript analysis, language practice, and the handoff to BoostVocab/Anki; it does not embed or reproduce the source video.

## Source content

Expected content includes, but is not limited to:

- Learning resources
- Science and facts
- Motivational content
- Daily vlogs

The feature should be topic-agnostic within ordinary short-form English content.

The source must be spoken primarily in English. Occasional non-English fragments may remain in the approved transcript for context but are excluded from language-item analysis. The app rejects a predominantly non-English source before lesson generation.

The target source length is 1–3 minutes. The app warns when a source exceeds three minutes and enforces a five-minute maximum in the first version.

## Selection principle

The lesson should prioritize language that either:

- is necessary to understand the source video's meaning; or
- is common and reusable enough to deserve active practice.

It should not turn every unfamiliar transcript fragment into an exercise or Anki candidate.

Each lesson contains at most 6–10 selected language items in total, ranked by comprehension value and reusability. Categories do not have quotas and may be empty when the transcript contains no worthwhile example.

CEFR is an estimated prioritization signal rather than a strict exclusion rule. The analyzer prioritizes B2–C2 language but may include an apparently lower-level item when its contextual use is subtle, easy to misunderstand, or essential to the video's meaning. Every selected item should state why it was included.

## Known product context

- The current product is a native macOS app.
- It is a private tool intended for one learner, not a distributed product.
- BoostVocab enriches learner-supplied words through a bundled Python/OpenAI agent.
- The product can persist learning material in Supabase and export vocabulary cards to Anki.

## Persistence

Generated lessons are saved to Supabase automatically so the learner can reopen them and continue studying.

Persisted lesson state includes:

- Source URL and platform metadata needed to identify the lesson
- Cleaned transcript and Meaning Overview
- Selected language items and their analysis
- Generated exercises
- Learner answers, feedback, and completion state
- Whether each item was exported to Anki

Downloaded video and extracted audio are temporary processing artifacts and are not saved with the lesson.

## Open questions

None blocking for v1. CEFR remains an explained estimate; the five-minute duration cap bounds transcript and processing size.

## Transcript acquisition research

Speech-to-text can generate a transcript from an audio file. The difficult boundary is obtaining media from an arbitrary platform URL:

- YouTube's official developer policies prohibit API clients from downloading audiovisual content or separating its audio without approval.
- TikTok's public Display API documents video metadata and embedded display, not arbitrary media/audio download for transcription.
- A compliant fallback is to let the learner upload a local media file they own or are authorized to use, transcribe it, and delete the temporary media after processing.
- Caption retrieval and manual transcript paste remain possible acquisition paths.

ADR 0003 records the safer distribution-oriented alternative; ADR 0004 records the accepted personal-use decision.

## Agreed transcript acquisition direction

Because Anki Mate is a private, personal-use tool, it may attempt best-effort local media acquisition from the submitted URL. The media exists only temporarily while audio is extracted and transcribed, then is deleted.

This is a convenience rather than a guaranteed capability. If platform changes, access restrictions, private content, authentication, or another error prevents acquisition, the learner can upload an authorized local media file or paste a transcript.

Transcript acquisition and lesson analysis are separate stages. After acquisition, the app shows an editable transcript and waits. Analysis begins only when the learner presses Analyze.

## Natural English Anki note

Transcript lesson items do not use the existing vocabulary-only note schema. They export to a separate Natural English note type while reusing the familiar BoostVocab-style add-to-Anki interaction.

Proposed fields:

- Expression or pattern
- Category
- Meaning and usage
- Original transcript example
- New natural example
- CEFR estimate
- Source URL

## Agreed practice model

For the 3–5 most reusable lesson items, practice includes both:

- Contextual recognition: for example, a cloze, usage choice, or sentence transformation.
- Active production: paraphrase a sentence or create a new example using the target language.

Production answers receive AI feedback on meaning, grammatical correctness, contextual appropriateness, and naturalness. Feedback should explain a correction and provide a natural revision rather than returning only a score.

All practice input is typed. Voice recording, pronunciation assessment, and spoken-response evaluation are explicitly outside the feature scope. Listening practice happens when the learner independently replays the source on YouTube or TikTok.

## Agreed lesson layout

Each lesson begins with a Meaning Overview, followed by the complete cleaned transcript. Selected language is highlighted inline, and each highlight links to its detailed analysis. The focused 6–10-item lesson follows the transcript.

The Meaning Overview contains:

- A 3–5 sentence summary
- The speaker's main point and supporting ideas
- Tone and register
- Implied meaning, cultural context, or references needed to follow the video

The overview and contextual notes stay brief. They explain what the speaker means; they do not independently research or verify factual claims. When truth is not established by the transcript, wording such as "the speaker claims" avoids presenting the claim as verified fact.

Each selected item exposes:

- One primary category and optional secondary category tags
- Meaning and usage
- Original source excerpt
- Estimated CEFR level
- Selection rationale
- New natural example
- Practice, when the item is among the 3–5 most reusable

## Explanation language

Lessons and AI feedback are written in clear English by default. A short Vietnamese gloss may be added only for a difficult sentence or a sentence that needs deeper structural analysis. The feature does not translate the complete transcript into Vietnamese.

## V1 scope boundary

The feature's job is to produce a high-quality analysis of an approved English transcript. The generated analysis is read-only in v1; the learner controls quality by correcting the transcript before pressing Analyze. Selected language may be exported to Anki, and lightweight typed practice remains available for the strongest items.

The learner performs replay and shadowing independently on YouTube or TikTok.

V1 does not include:

- Embedded video playback
- Voice recording or pronunciation assessment
- Guided or verified shadowing
- Fact-checking or external research
- Analysis version history
- Editing generated analysis
- Goals, streaks, or weekly scheduling features

## V1 acceptance criteria

- A YouTube or TikTok URL for a primarily English source of at most five minutes can start transcript acquisition.
- Acquisition failure offers local media upload and transcript paste fallbacks.
- Temporary media is removed after transcription, including failure cleanup where possible.
- The learner can review and edit the full transcript before analysis.
- Analysis never begins until the learner presses Analyze.
- The lesson contains a concise Meaning Overview and the complete approved transcript with inline highlights.
- The analyzer returns no more than 10 unique high-value items and does not fill categories artificially.
- Each item has one primary category, optional secondary tags, contextual explanation, source excerpt, CEFR estimate, selection rationale, and a new natural example.
- Short Vietnamese support appears only for genuinely difficult sentence-level analysis.
- The 3–5 strongest reusable items may include recognition and typed production practice with naturalness feedback.
- Lessons and progress save to Supabase; source media does not.
- A selected item exports once to the Natural English Anki note type through AnkiConnect.
- The lesson provides a clear link back to the original source for independent replay and shadowing.
