# Transcript Lessons — Product Discovery

Status: Discovery

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

## Agreed learning loop

1. The learner submits a YouTube or TikTok URL.
2. The system analyzes the transcript of a short video, normally 1–3 minutes long.
3. The lesson explains language needed to understand the video's ideas deeply, with emphasis on grammar patterns, collocations, slang, and other important B2-and-above usage.
4. The 3–5 most reusable items receive both a contextual recognition exercise and an active production task.
5. The learner may send selected items through a BoostVocab-style action into a dedicated Natural English Anki note type.
6. After understanding the lesson, the learner returns to YouTube or TikTok and watches the original video again to strengthen listening comprehension.

Video playback remains on the source platform. The app focuses on transcript analysis, language practice, and the handoff to BoostVocab/Anki; it does not embed or reproduce the source video.

## Source content

Expected content includes, but is not limited to:

- Learning resources
- Science and facts
- Motivational content
- Daily vlogs

The feature should be topic-agnostic within ordinary short-form English content.

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

## Open questions

- Is there a first, unaided listen and a comprehension check before transcript analysis is revealed?
- When captions are unavailable, should the learner upload a media file they are authorized to use, paste a transcript, or receive an unsupported-source error?
- What evidence and confidence should accompany an estimated CEFR label?
- How should overlapping categories be handled?
- Does the first version accept typed production only, or spoken responses as well?
- How should exercise progress and attempts be saved?
- What gets saved and edited beyond selected Natural English Anki notes?
- What limits apply to video duration, transcript size, cost, and processing time?

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
